// SPDX-License-Identifier: MIT
//                 владелец контракта должен перевести 1кк остальным участникам и
//                 в основном не сможет участвовать в голосованиях
pragma solidity ^0.7.6;

// Интерфейс токена
interface ChangableToken {
    function changeSymbol(string memory _symbol) external;
    function changeName(string memory _name) external;
    function balanceOf(address _user) external returns (uint);
    function viewOwner() external returns (address);
    function viewList(uint _uint) external returns (address);
    function viewList1(address _address) external returns (uint);
    function useList(string memory _name, string memory _func, uint _uint, address _address) external;
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

// Контракт ДАО
contract DAOContract {
    using SafeMath for uint;

    // Переменная для хранения токена
    ChangableToken public token;
    
    uint private count = 1;
    uint private timeOut = 1 days; // Тайм-аут ожидания окончания голосования
    uint private time;
    
    // Минимальное число голосов
    uint public minVotes = 600000;

    // Переменная для хранения состояния голосования
    bool public voteActive = false;

    // Структура для голосов
    struct Votes {
        string typeOfPolling; // Тип голосования
        string proposalValue; // Предложенное значение
        string addtnlValue; // Дополнительное значение
        uint current; // Текущее значение голосов
        uint numberOfVotes; // Общее количество голосов
    }

    // Переменная для структуры голосов
    Votes public election;

    // Функция инициализации (принимает адрес токена)
    constructor(ChangableToken _token) {
        token = _token;
    }

    function strToBytes32(string memory _string) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(_string));
    }
    
    // Функция для предложения нового символа
    function newPolling(string memory _proposalVoting, string memory _value, string memory _additionalValue) public {

        // Проверяем, что голосование не идет
        require(!voteActive);
        require(token.balanceOf(msg.sender) > 0);
        // Проверяем наличие указанной функции
        require(
            strToBytes32(_proposalVoting) == strToBytes32("newName")
            || strToBytes32(_proposalVoting) == strToBytes32("newSymbol")
            || strToBytes32(_proposalVoting) == strToBytes32("newPolling"));
        
        // Ограничение на символы
        bytes memory bs = bytes(_value);
        require(bs.length <= 32);
        bs = bytes(_additionalValue);
        require(bs.length <= 256);
        
        if (strToBytes32(_proposalVoting) == strToBytes32("newSymbol")) {
            election.typeOfPolling = "New Symbol"; // Тип опроса
            election.proposalValue = _value; // Предложенное значение
        }
        if (strToBytes32(_proposalVoting) == strToBytes32("newName")) {
            election.typeOfPolling = "New Name"; // Тип опроса
            election.proposalValue = _value; // Предложенное значение
        }
        if (strToBytes32(_proposalVoting) == strToBytes32("newPolling")){
            election.typeOfPolling = "Polling"; // Тип опроса
            election.proposalValue = _value; // Название опроса
            election.addtnlValue = _additionalValue; // Краткое описание
        }
        
        voteActive = true;
        time = block.timestamp; // Время открытия голосования
    }

    // Функция для голосования
    function vote(string memory _vote) public {
        require(
            strToBytes32(_vote) == strToBytes32("true")
            || strToBytes32(_vote) == strToBytes32("false"));
        // Проверяем, что голосование идет
        require(voteActive);
        // Проверяем, что есть хотя бы один токен
        require(token.balanceOf(msg.sender) > 0);
        require(token.viewList1(msg.sender) == 0); // Проверка на повторное участие
        
        if (strToBytes32(_vote) == strToBytes32("true")){
            election.current = election.current.add(token.balanceOf(msg.sender));}
        else {
            election.current = election.current.sub(token.balanceOf(msg.sender));}

        // Если владелец проголосовал, то минимальное количество голосов увеличивается
        if (msg.sender == token.viewOwner()) {
                minVotes = minVotes.add(500000);}
        
        election.numberOfVotes = election.numberOfVotes.add(token.balanceOf(msg.sender));
        token.useList("votersList", "change", count, msg.sender); // Присваивание уникального номера (нигде не отображается)
        token.useList("votersList1", "change", count, msg.sender);
        count++;
    }
    // Функция для смены символа
    function toSumUp() public {

        // Проверяем, что голосование активно
        require(voteActive);
        // Проверяем, что время создания голосования создано
        require(time != 0);

        // Проверяем, что было достаточное количество голосов или время истекло
        require(
            election.numberOfVotes >= minVotes
            || time + timeOut < block.timestamp);
        
            // Логика для подведения итогов
            if (election.current > 0) {
                // Изменение тикера
                if (
                    strToBytes32(election.typeOfPolling)
                    == strToBytes32("New Symbol")) {
                        
                        token.changeSymbol(election.proposalValue);
                }
                
                // Изменение имени токена
                if (
                    strToBytes32(election.typeOfPolling)
                    == strToBytes32("New Name")) {
                        
                        token.changeName(election.proposalValue);
                }
            }
    
            // Сбрасываем все переменные для голосования
            election.numberOfVotes = 0;
            election.current = 0;
            
            voteActive = false;
            minVotes = 600000;
            time = 0;
            
            election.proposalValue = "";
            election.typeOfPolling = "";
            election.addtnlValue = "";
    
            // Удаляем списки голосовавших
            for(uint i = 0 ; i<count; i++) {
                token.useList("votersList1", "delete", i, token.viewList(i));
                token.useList("votersList", "delete", i, msg.sender);
            }
            count = 1;
    }
}
