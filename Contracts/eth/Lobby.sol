// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./../Ownable.sol";
import "./SharedData.sol";
import "./Battle.sol";
import "./NFT.sol";

contract Lobby is Ownable, SharedData {
    uint256 public gameCount = 0;
    mapping(uint256 => address) public gamesViaIndex;
    mapping(address => uint256) public gamesViaAddress;
    address[] public openGames;
    uint256[] public openGamesBids;
    mapping(address => address[]) public currentUserGames;
    mapping(address => uint256[]) public currentUserGamesBids;
    mapping(address => mapping(address => uint256)) public indexInCurrentUserGames;
    mapping(address => uint256) public indexInOpenGames;

    mapping(uint256 => Statuses) public statusViaId;
    mapping(address => Statuses) public statusViaAddress;
    mapping(address => address[]) public userGames;

    address public nftAddress;

    event WithdrawAdminProcessed(
        address caller,
        uint256 amount,
        uint256 timestamp
    );

    event GameCreated(
        address owner,
        address game,
        uint256 bid,
        uint256 usedNft,
        uint256 gameIndex,
        uint256 timestamp
    );
    event UserJoinedGame(
        address user,
        address game,
        uint256 bid,
        uint256 usedNft,
        uint256 timestamp
    );
    event SearchStopped(
        address user,
        address game,
        uint256 timestamp
    );
    event GameEnded(
        address game,
        address winner,
        uint256 timestamp
    );

    constructor(address _nftAddress) {
        nftAddress = _nftAddress;
    }

    function createPublicGame(uint256 _usedNft) public payable {
        require(msg.value > 0, "Value can't be 0");

        gameCount++;
        address gameAddress = address(
            new Battle(
                address(this),
                nftAddress,
                msg.value,
                msg.sender,
                _usedNft,
                gameCount
            )
        );

        gamesViaIndex[gameCount] = gameAddress;
        gamesViaAddress[gameAddress] = gameCount;
        statusViaId[gameCount] = Statuses.PREPARATION;
        statusViaAddress[gameAddress] = Statuses.PREPARATION;
        indexInOpenGames[gameAddress] = openGames.length;
        openGames.push(gameAddress);
        openGamesBids.push(msg.value);
        userGames[msg.sender].push(gameAddress);
        indexInCurrentUserGames[msg.sender][gameAddress] = currentUserGames[msg.sender].length;
        currentUserGames[msg.sender].push(gameAddress);
        currentUserGamesBids[msg.sender].push(msg.value);

        emit GameCreated(
            msg.sender,
            gameAddress,
            msg.value,
            _usedNft,
            gameCount,
            block.timestamp
        );
    }

    function getOpenGamesList() public view returns (address[] memory){
        return openGames;
    }
    function getOpenGamesBids() public view returns (uint256[] memory){
        return openGamesBids;
    }

    function getUserGamesList(address user) public view returns (address[] memory){
        return userGames[user];
    }

    function getUserCurrentGamesList(address user) public view returns (address[] memory){
        return currentUserGames[user];
    }

    function getUserCurrentGamesBidsList(address user) public view returns (uint256[] memory){
        return currentUserGamesBids[user];
    }

    function joinGame(
        address gameAddress,
        uint256 _usedNft
    ) public payable {
        require(statusViaAddress[gameAddress] == Statuses.PREPARATION, "Game must be in search");

        uint256 index = indexInOpenGames[gameAddress];

        require(msg.value >= openGamesBids[index], "Not enough money");

        if (msg.value > openGamesBids[index]) {
            payable(msg.sender).transfer(msg.value - openGamesBids[index]);
        }

        Battle battleContract = Battle(gameAddress);
        battleContract.joinBattle(msg.sender, _usedNft);

        statusViaId[gamesViaAddress[gameAddress]] = Statuses.IN_PROGRESS;
        statusViaAddress[gameAddress] = Statuses.IN_PROGRESS;
        userGames[msg.sender].push(gameAddress);
        indexInCurrentUserGames[msg.sender][gameAddress] = currentUserGames[msg.sender].length;
        currentUserGames[msg.sender].push(gameAddress);
        currentUserGamesBids[msg.sender].push(openGamesBids[index]);

        emit UserJoinedGame(
            msg.sender,
            gameAddress,
            openGamesBids[index],
            _usedNft,
            block.timestamp
        );

        removeGameFromArray(gameAddress);
    }

    function joinRandomLobby(uint256 _usedNft) public payable {
        require(msg.value > 0, "Value can't be 0");

        uint256 foundIndex = 0;
        uint256 minimalBet = 0;

        for(uint i = 0; i < openGamesBids.length; i++) {
            if (openGamesBids[i] == msg.value) {
                foundIndex = i;
                minimalBet = msg.value;

                break;
            } else if (openGamesBids[i] < msg.value && openGamesBids[i] > minimalBet) {
                foundIndex = i;
                minimalBet = openGamesBids[i];
            }
        }

        require(minimalBet > 0, "Game not found");

        if (msg.value > openGamesBids[foundIndex]) {
            payable(msg.sender).transfer(msg.value - openGamesBids[foundIndex]);
        }

        address foundAddress = openGames[foundIndex];

        Battle battleContract = Battle(foundAddress);
        battleContract.joinBattle(msg.sender, _usedNft);

        statusViaId[gamesViaAddress[foundAddress]] = Statuses.IN_PROGRESS;
        statusViaAddress[foundAddress] = Statuses.IN_PROGRESS;
        userGames[msg.sender].push(foundAddress);
        indexInCurrentUserGames[msg.sender][foundAddress] = currentUserGames[msg.sender].length;
        currentUserGames[msg.sender].push(foundAddress);
        currentUserGamesBids[msg.sender].push(openGamesBids[foundIndex]);

        emit UserJoinedGame(
            msg.sender,
            foundAddress,
            openGamesBids[foundIndex],
            _usedNft,
            block.timestamp
        );

        removeGameFromArray(foundAddress);
    }

    function removeGameFromArray(address game) internal {
        uint256 index = indexInOpenGames[game];

        openGamesBids[index] = openGamesBids[openGamesBids.length - 1];

        if (openGamesBids[index] > 0) {
            indexInOpenGames[openGames[index]] = index;
        }

        openGamesBids.pop();
        openGames[index] = openGames[openGames.length - 1];
        openGames.pop();

        indexInOpenGames[game] = 0;
    }

    function stopGameSearch(address game) public {
        require(statusViaAddress[game] == Statuses.PREPARATION, "Game must be in search");

        Battle battleContract = Battle(game);
        address owner = battleContract.firstPlayer();
        require(msg.sender == owner, "Only owner can stop the game");


        payable(msg.sender).transfer(openGamesBids[indexInOpenGames[game]]);

        removeGameFromArray(game);

        statusViaId[gamesViaAddress[game]] = Statuses.FINISHED;
        statusViaAddress[game] = Statuses.FINISHED;

        uint256 index = indexInCurrentUserGames[msg.sender][game];

        battleContract.stopBattle();

        currentUserGames[msg.sender][index] = currentUserGames[msg.sender][currentUserGames[msg.sender].length - 1];
        currentUserGames[msg.sender].pop();
        currentUserGamesBids[msg.sender][index] = currentUserGamesBids[msg.sender][currentUserGamesBids[msg.sender].length - 1];
        currentUserGamesBids[msg.sender].pop();

        indexInCurrentUserGames[msg.sender][game] = 0;

        emit SearchStopped(
            msg.sender,
            game,
            block.timestamp
        );
    }

    function endGame(address winner) public payable {
        require(gamesViaAddress[msg.sender] != 0, "Sender must be battle contract");

        Battle currentGame = Battle(msg.sender);

        address firstPlayer = currentGame.firstPlayer();
        address secondPlayer = currentGame.secondPlayer();

        uint256 firstIndex = indexInCurrentUserGames[firstPlayer][msg.sender];
        currentUserGames[firstPlayer][firstIndex] = currentUserGames[firstPlayer][currentUserGames[firstPlayer].length - 1];
        currentUserGames[firstPlayer].pop();
        currentUserGamesBids[firstPlayer][firstIndex] = currentUserGamesBids[firstPlayer][currentUserGamesBids[firstPlayer].length - 1];
        currentUserGamesBids[firstPlayer].pop();

        uint256 secondIndex = indexInCurrentUserGames[secondPlayer][msg.sender];
        currentUserGames[secondPlayer][secondIndex] = currentUserGames[secondPlayer][currentUserGames[secondPlayer].length - 1];
        currentUserGames[secondPlayer].pop();
        currentUserGamesBids[secondPlayer][secondIndex] = currentUserGamesBids[secondPlayer][currentUserGamesBids[secondPlayer].length - 1];
        currentUserGamesBids[secondPlayer].pop();

        uint256 prize = currentGame.bid() * 2;

        sendAdminReward(prize);

        prize = prize * (100 - ADMIN_PERCENTAGE) / 100;

        payable(winner).transfer(prize);

        emit GameEnded(
            msg.sender,
            winner,
            block.timestamp
        );
    }

    function sendAdminReward(uint256 _amount) internal {
        uint256 value = _amount * ADMIN_PERCENTAGE / 100 ;

        uint256 percent = 0;

        for (uint256 i = 0; i < admins.length; i++) {
            percent = percent + percentages[admins[i]];
        }

        require(percent == 10000, "Total admin percent must be 10000 or 100,00%");

        for (uint256 i = 0; i < admins.length; i++) {
            uint256 amount = value * percentages[admins[i]] / 10000;
            payable(admins[i]).transfer(amount);
        }

        emit WithdrawAdminProcessed(
            msg.sender,
            value,
            block.timestamp
        );
    }
}
