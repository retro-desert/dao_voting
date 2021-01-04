// SPDX-License-Identifier: GPL-3.0
// Список дел:
//              2) сделать планку по времени, количеству монет (?) для голосующих
//              3) придумать новые формы голосования (изменить значение в списке)
//              4) сначала провести ico, затем проводить голосование на этой платформе -
//                 владелец контракта должен перевести 1кк на адрес смарт-контракта и
//                 в основном не сможет участвовать в голосованиях
pragma solidity ^0.7.6;

// Интерфейс токена
interface ChangableToken {
    function changeSymbol(string memory _symbol) external;
    function changeName(string memory _name) external;
    function balanceOf(address _user) external returns (uint256);
    function viewOwner() external payable returns (address);
    function viewList(uint _uint) external returns (address);
    function viewList1(address _address) external returns (uint);
    function useList(string memory _name, string memory _func, uint _uint, address _address) external;
}

// Контракт ДАО
contract DAOContract {

    // Переменная для хранения токена
    ChangableToken public token;

    uint private count = 1;
    uint private timeOut = 1 days;
    uint private time;

    // Минимальное число голосов
    uint public minVotes = 600000;

    // Переменная для хранения состояния голосования
    bool public voteActive = false;

    // Стукрутра для голосов
    struct Votes {
        string typeOfPolling; // Тип голосования
        string proposalValue; // Предложенное значение
        int current;
        uint numberOfVotes;
    }

    // Переменная для структуры голосов
    Votes public election;

    // Функция инициализации ( принимает адрес токена)
    constructor(ChangableToken _token) {
        token = _token;
    }

    // Функция для предложения нового символа
    function newPolling(string memory _proposalVoting, string memory _value) public {

        // Проверяем, что голосвание не идет
        require(!voteActive);
        require(int(token.balanceOf(msg.sender)) > 0);
        // Проверяем наличие указанной функции
        require(keccak256(abi.encodePacked(_proposalVoting)) == keccak256(abi.encodePacked("newName")) || keccak256(abi.encodePacked(_proposalVoting)) == keccak256(abi.encodePacked("newSymbol")));
        if (keccak256(abi.encodePacked(_proposalVoting)) == keccak256(abi.encodePacked("newSymbol"))) {
            election.typeOfPolling = "New Symbol";
            election.proposalValue = _value;
        }
        if (keccak256(abi.encodePacked(_proposalVoting)) == keccak256(abi.encodePacked("newName"))) {
            election.typeOfPolling = "New Name";
            election.proposalValue = _value;
        }

        voteActive = true;
        time = block.timestamp;
    }

    // Функция для голосования
    function vote(bool _vote) public {
        // Проверяем, что голосование идет
        require(voteActive);
        // Проверяем, что есть хотя бы одна акция
        require(int(token.balanceOf(msg.sender)) > 0);
        // Логика для голосования
        if (_vote){
            require(token.viewList1(msg.sender) == 0); // Проверка на повторное участие

            // Если владелец проголосовал, то минимальное количество голосов увеличивается
            if (token.viewOwner() == msg.sender) {
                minVotes += 500000;
            }
            election.current += int(token.balanceOf(msg.sender));

            token.useList("votersList", "change", count, msg.sender); // Присваивание уникального номера (нигде не отображается)
            token.useList("votersList1", "change", count, msg.sender);
            count++;
        }
        else {
            require(token.viewList1(msg.sender) == 0); // Проверка на повторное участие
            // Если владелец проголосовал, то минимальное количество голосов увеличивается
            if (msg.sender == token.viewOwner()) {
                minVotes += 500000;
            }
            election.current -= int(token.balanceOf(msg.sender));

            token.useList("votersList", "change", count, msg.sender); // Присваивание уникального номера (нигде не отображается)
            token.useList("votersList1", "change", count, msg.sender);
            count++;
        }

        election.numberOfVotes += token.balanceOf(msg.sender);
    }

    // Функция для смены символа
    function toSumUp() public {

        // Проверяем, что голосование активно
        require(voteActive);
        // Проверяем, что время создания голосования создано
        require(time != 0);

        // Проверяем, что было достаточное количество голосов или время истекло
        if (election.numberOfVotes >= minVotes || time + timeOut < block.timestamp) {

            // Логика для подведения итогов
            if (election.current > 0) {
                // Изменение тикера
                if (keccak256(abi.encodePacked(election.typeOfPolling)) == keccak256(abi.encodePacked("New Symbol"))) {
                    token.changeSymbol(election.proposalValue);
                }

                // Изменение имени токена
                if (keccak256(abi.encodePacked(election.typeOfPolling)) == keccak256(abi.encodePacked("New Name"))) {
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

            // Удаляем списки голосовавших
            for(uint i = 0 ; i<count; i++) {
                token.useList("votersList1", "delete", i, token.viewList(i));
                token.useList("votersList", "delete", i, msg.sender);
            }
            count = 1;
        }

        // Иначе отклоняем транзакцию
        else {
            revert();
        }
    }
}