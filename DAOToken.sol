// SPDX-License-Identifier: MIT
// Указываем версию для компилятора
pragma solidity ^0.7.6;

// Контракт для установки прав
contract OwnableWithDAO{

    // Переменная для хранения владельца контракта
    address public owner;

    // Переменная для хранения адреса DAO
    address public daoContract;

    // Конструктор, который при создании инициализирует переменную с владельцем
    constructor() {
        owner = msg.sender;
    }

    // Модификатор для защиты от вызовов не создателя контракта
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }


    // Модификатор для защиты от вызовов не со стороны DAO
    modifier onlyDAO(){
        require(msg.sender == daoContract);
        _;
    }

    // Функция для замены владельца
    function transferOwnership(address newOwner) onlyOwner public{
        require(newOwner != address(0));
        owner = newOwner;
    }

}

/*
   SafeMath
   Математические операторы с проверками ошибок
 */
library SafeMath {
  function mul(uint _a, uint _b) internal pure returns (uint) {
    uint c = _a * _b;
    assert(_a == 0 || c / _a == _b);
    return c;
  }
  function div(uint _a, uint _b) internal pure returns (uint) {
    // assert(b > 0); // Solidity автоматически выбрасывает ошибку при делении на ноль, так что проверка не имеет смысла
    uint c = _a / _b;
    // assert(a == b * c + a % b); // Не существует случая, когда эта проверка не была бы пройдена
    return c;
  }
  function sub(uint _a, uint _b) internal pure returns (uint) {
    assert(_b <= _a);
    return _a - _b;
  }
  function add(uint _a, uint _b) internal pure returns (uint) {
    uint c = _a + _b;
    assert(c >= _a);
    return c;
  }
}

// Контракт для остановки некоторых операций
contract Stoppable is OwnableWithDAO{
    
    // Функция для установки / замены контракта DAO
    function setDAOContract(address _newDAO) onlyOwner public {
        // Нельзя сменить контракт, пока голосование активно
        // (защита от утечки списков голосующих)
        require(votersList[1] == address(0));
        daoContract = _newDAO;
    }
    
    // Функция для просмотра создателя извне
    function viewOwner() public onlyDAO view returns (address _owner) {
        return owner;
    }

    // Списки голосующих
    mapping (uint => address) private votersList; // default: private
    mapping (address => uint) private votersList1;
    
    // Функция для просмотра первого списка извне
    function viewList(uint _uint) public onlyDAO view returns (address _address) {
        return votersList[_uint];
    }
    
    // Функция для просмотра второго списка извне
    function viewList1(address _address) public onlyDAO view returns (uint _uint) {
        return votersList1[_address];
    }
    
    function strToBytes32(string memory _string) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(_string));
    }
    
    // Функция для взаимодействия со списками извне
    function useList(string memory _name, string memory _func, uint _uint, address _address) public onlyDAO {
        if (strToBytes32(_name) == strToBytes32("votersList")) {
            if (strToBytes32(_func) == strToBytes32("change")) {
                votersList[_uint] = _address;
            }
            if (strToBytes32(_func) == strToBytes32("delete")) {
                delete votersList[_uint];
            }
        }
        if (strToBytes32(_name) == strToBytes32("votersList1")) {
            if (strToBytes32(_func) == strToBytes32("change")) {
                votersList1[_address] = _uint;
            }
            if (strToBytes32(_func) == strToBytes32("delete")) {
                delete votersList1[_address];
            }
        }
    }
    // Модификатор для проверки возможности выполнения функции
    modifier stoppable(address _address) {
        require(votersList1[_address] == 0);
        _;
    }
}


// Инициализация контракта
contract DAOToken is Stoppable {
    using SafeMath for uint;

    // Объявляем переменную в которой будет название токена
    string public name;
    // Объявляем переменную в которой будет символ токена
    string public symbol;
    // Объявляем переменную в которой будет число нулей токена
    uint8 public decimals;

    // Объявляем переменную в которой будет храниться общее число токенов
    uint public totalSupply;

    // Объявляем маппинг для хранения балансов пользователей
    mapping (address => uint) internal balances;
    // Объявляем маппинг для хранения одобренных транзакций
    mapping (address => mapping (address => uint)) public allowance;

    // Объявляем эвент для логгирования события перевода токенов
    event Transfer(address from, address to, uint value);
    // Объявляем эвент для логгирования события одобрения перевода токенов
    event Approval(address from, address to, uint value);


    // Функция инициализации контракта
    constructor(){
        // Указываем число нулей
        decimals = 0;
        // Объявляем общее число токенов, которое будет создано при инициализации
        totalSupply = 1500000 * (10 ** uint(decimals));
        // 10000000 * (10^decimals)

        // "Отправляем" все токены на баланс того, кто инициализировал создание контракта токена
        balances[msg.sender] = totalSupply;

        // Указываем название токена
        name = "DAOCoin";
        // Указываем символ токена
        symbol = "DAO";
    }

    // Внутренняя функция для перевода токенов
    function transfer(address _to, uint _value) public stoppable(msg.sender) returns (bool success) {
        require(_to != address(0));
        require(balances[msg.sender] >= _value);
        
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // Функция для перевода "одобренных" токенов
    function transferFrom(address _from, address _to, uint _value) public stoppable(msg.sender) returns (bool success) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        // Проверка, что токены были выделены аккаунтом _from для аккаунта _to
        require(_value <= allowance[_from][_to]);
        
        // Уменьшаем число "одобренных" токенов
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        // Отправка токенов
        transfer(_to, _value);
        
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }

    // Функция для "одобрения" перевода токенов
    function approve(address _to, uint _value) public stoppable(msg.sender) returns (bool success) {
        // Запись в мапппинг число "одобренных" токенов
        allowance[msg.sender][_to] = _value;
        // Вызов ивента для логгирования события одобрения перевода токенов
        emit Approval(msg.sender, _to, _value);
        return true;
    }

    // Функция для смены тикера
    function changeSymbol(string memory _symbol) public onlyDAO {
        symbol = _symbol;
    }
    
    // Функция для смены названия токена
    function changeName(string memory _name) public onlyDAO {
        name = _name;
    }
}

contract BurnableToken is DAOToken {
    using SafeMath for uint;
    event Burn(address indexed burner, uint256 value);
    /*
      Сжигает определённое количество токенов.
    */
    function burn(uint256 _value) public {
        require(_value > 0);
        require(_value <= balances[msg.sender]);
        // нет необходимости проверять value <= totalSupply, так как это будет подразумевать, что
        // баланс отправителя больше, чем totalSupply, что должно привести к ошибке
        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        emit Burn(burner, _value);
  }
}
