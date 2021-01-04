// SPDX-License-Identifier: GPL-3.0
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

    // Модификатор для защиты от вызовов не создалетя контракта
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

    // Функция для установки / замены контракта DAO
    function setDAOContract(address newDAO) onlyOwner public {
        daoContract = newDAO;
    }
}


// Контракт для остановки некоторых операций
contract Stoppable is OwnableWithDAO{

    function viewOwner() public onlyDAO view returns (address _owner) {
        return owner;
    }

    mapping (uint => address) private votersList; // default: private
    mapping (address => uint) private votersList1;

    function viewList(uint _uint) public onlyDAO view returns (address _address) {
        return votersList[_uint];
    }

    function viewList1(address _address) public onlyDAO view returns (uint _uint) {
        return votersList1[_address];
    }

    function useList(string memory _name, string memory _func, uint _uint, address _address) public onlyDAO {
        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("votersList"))) {
            if (keccak256(abi.encodePacked(_func)) == keccak256(abi.encodePacked("change"))) {
                votersList[_uint] = _address;
            }
            if (keccak256(abi.encodePacked(_func)) == keccak256(abi.encodePacked("delete"))) {
                delete votersList[_uint];
            }
        }
        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("votersList1"))) {
            if (keccak256(abi.encodePacked(_func)) == keccak256(abi.encodePacked("change"))) {
                votersList1[_address] = _uint;
            }
            if (keccak256(abi.encodePacked(_func)) == keccak256(abi.encodePacked("delete"))) {
                delete votersList1[_address];
            }
        }
    }
    // Модификатор для проверки возможности выполнения функции
    modifier stoppable(address _address) {
        require(uint(votersList1[_address]) == uint(0));
        _;
    }
}


// Инициализация контракта
contract DAOToken is Stoppable {

    // Объявляем переменную в которой будет название токена
    string public name;
    // Объявляем переменную в которой будет символ токена
    string public symbol;
    // Объявляем переменную в которой будет число нулей токена
    uint8 public decimals;

    // Объявляем переменную в которой будет храниться общее число токенов
    uint256 public totalSupply;

    // Объявляем маппинг для хранения балансов пользователей
    mapping (address => uint256) public balances;
    // Объявляем маппинг для хранения одобренных транзакций
    mapping (address => mapping (address => uint256)) public allowance;

    // Объявляем эвент для логгирования события перевода токенов
    event Transfer(address from, address to, uint256 value);
    // Объявляем эвент для логгирования события одобрения перевода токенов
    event Approval(address from, address to, uint256 value);


    // Функция инициализации контракта
    constructor(){
        // Указываем число нулей
        decimals = 0;
        // Объявляем общее число токенов, которое будет создано при инициализации
        totalSupply = 1500000 * (10 ** uint256(decimals));
        // 10000000 * (10^decimals)

        // "Отправляем" все токены на баланс того, кто инициализировал создание контракта токена
        balances[msg.sender] = totalSupply;

        // Указываем название токена
        name = "DAOCoin";
        // Указываем символ токена
        symbol = "DAO";
    }

    // Внутренняя функция для перевода токенов
    function transfer(address _to, uint256 _value) public stoppable(msg.sender) returns (bool success) {
        require(_to != payable(0x0));
        require(balances[msg.sender] >= _value);
        require(balances[_to] + _value >= balances[_to]);

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // Функция для перевода "одобренных" токенов
    function transferFrom(address _from, address _to, uint256 _value) public stoppable(msg.sender) returns (bool success) {
        // Проверка, что токены были выделены аккаунтом _from для аккаунта _to
        require(_value <= allowance[_from][_to]);

        // Уменьшаем число "одобренных" токенов
        allowance[_from][_to] -= _value;
        // Отправка токенов
        transfer(_to, _value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }

    // Функция для "одобрения" перевода токенов
    function approve(address _to, uint256 _value) public stoppable(msg.sender) returns (bool success) {
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