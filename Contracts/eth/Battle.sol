// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./../Ownable.sol";
import "./NFT.sol";
import "./Lobby.sol";
import "./SharedData.sol";

contract Battle is Ownable, SharedData {
    Lobby public lobbyContract;
    NFT public nftContract;

    uint256 public bid;
    address public firstPlayer;
    uint256 public firstPlayerCard;
    address public secondPlayer;
    uint256 public secondPlayerCard;
    bytes32 firstHash;
    bytes32 secondHash;
    string firstParsedHash;
    string secondParsedHash;
    uint256 firstBoost;
    uint256 secondBoost;
    address public winner;

    uint256 public gameId;
    Stages public currentStage;
    uint256 public roundCount = 0;
    uint256 public roundStartedAt = 0;
    uint256 public currentStepOwner = 0;

    // round number => player address => actions (first 3 from game and 4 - boost)
    mapping(uint256 => mapping(address => uint256[])) public roundHistory;

    CurrentStats public firstPlayerStats;
    CurrentStats public secondPlayerStats;

    event PreparationStageStarts(
        uint256 timestamp
    );
    event HashSendingStageStarts(
        uint256 timestamp,
        uint256 round
    );
    event HashApprovingStageStarts(
        uint256 timestamp,
        uint256 round
    );
    event BoostSelectStageStarts(
        uint256 timestamp,
        uint256 round
    );
    event FinishStageStarts(
        address winner,
        uint256 timestamp
    );

    event UserSentHash(
        address user,
        uint256 timestamp
    );
    event UserSpecificationsChanged(
        address user,
        uint256 timestamp,
        uint256 maxHp,
        uint256 currentHp,
        uint256 maxEnergy,
        uint256 energy,
        uint256 attack,
        uint256 defence,
        uint256 healAmount,
        uint256 energyHealAmount
    );

    constructor(
        address _lobbyContract,
        address _nftContract,
        uint256 _bid,
        address _firstPlayer,
        uint256 _firstPlayerCard,
        uint256 _gameId
    ) {
        lobbyContract = Lobby(_lobbyContract);
        nftContract = NFT(_nftContract);
        bid = _bid;
        firstPlayer = _firstPlayer;
        firstPlayerCard = _firstPlayerCard;
        gameId = _gameId;

        if (_firstPlayerCard == 0) {
            firstPlayerStats = CurrentStats(
                defaultStats.hp,
                defaultStats.hp,
                defaultStats.energy,
                defaultStats.energy,
                defaultStats.attack,
                defaultStats.defence,
                HEAL_AMOUNT,
                ENERGY_HEAL_AMOUNT
            );
        } else {
            (uint256 hp, uint256 energy, uint256 attack, uint256 defence) = nftContract.nftStats(_firstPlayerCard);
            firstPlayerStats = CurrentStats(
                hp,
                hp,
                energy,
                energy,
                attack,
                defence,
                HEAL_AMOUNT,
                ENERGY_HEAL_AMOUNT
            );
        }

        currentStage = Stages.PREPARATION;
        emit PreparationStageStarts(block.timestamp);
    }

    function joinBattle(
        address _user,
        uint256 _playerCard
    ) public {
        require(msg.sender == address(lobbyContract), "Sender must be only lobby contract");
        require(currentStage == Stages.PREPARATION, "Stage must be preparation");
        require(_user != firstPlayer, "Users can't be the same");

        secondPlayer = _user;
        secondPlayerCard = _playerCard;

        if (_playerCard == 0) {
            secondPlayerStats = CurrentStats(
                defaultStats.hp,
                defaultStats.hp,
                defaultStats.energy,
                defaultStats.energy,
                defaultStats.attack,
                defaultStats.defence,
                HEAL_AMOUNT,
                ENERGY_HEAL_AMOUNT
            );
        } else {
            (uint256 hp, uint256 energy, uint256 attack, uint256 defence) = nftContract.nftStats(_playerCard);
            secondPlayerStats = CurrentStats(
                hp,
                hp,
                energy,
                energy,
                attack,
                defence,
                HEAL_AMOUNT,
                ENERGY_HEAL_AMOUNT
            );
        }

        currentStage = Stages.HASH_SENDING;
        roundCount++;
        roundStartedAt = block.timestamp;
        currentStepOwner = block.timestamp % 2;

        emit HashSendingStageStarts(
            block.timestamp,
            roundCount
        );
    }

    function stopBattle() public {
        require(msg.sender == address(lobbyContract), "Sender must be only lobby contract");
        require(currentStage == Stages.PREPARATION, "Stage must be preparation");

        currentStage = Stages.FINISHED;

        emit FinishStageStarts(
            firstPlayer,
            block.timestamp
        );
    }

    function getUserMove(uint256 _round, address _user) public view returns (uint256[] memory) {
        return roundHistory[_round][_user];
    }

    function setHash(bytes32 hash) public {
        require(currentStage == Stages.HASH_SENDING, "Stage must be hash sending");
        require(msg.sender == firstPlayer || msg.sender == secondPlayer, "Sender must be player");

        if (msg.sender == firstPlayer && firstHash == 0) {
            firstHash = hash;
        } else if (msg.sender == secondPlayer && secondHash == 0) {
            secondHash = hash;
        }

        if (firstHash != 0 && secondHash != 0) {
            currentStage = Stages.HASH_APPROVING;

            emit HashApprovingStageStarts(
                block.timestamp,
                roundCount
            );
        }

        emit UserSentHash(
            msg.sender,
            block.timestamp
        );
    }

    function approveHash(string memory rawHash) public {
        require(currentStage == Stages.HASH_APPROVING, "Stage must be hash approving");
        require(msg.sender == firstPlayer || msg.sender == secondPlayer, "Sender must be player");

        bytes32 generatedHash = sha256(bytes(rawHash));

        if (msg.sender == firstPlayer && firstHash != 0) {
            require(generatedHash == firstHash, "Raw data and received must be equal");

            firstParsedHash = rawHash;
            firstHash = 0;
        } else if (msg.sender == secondPlayer && secondHash != 0) {
            require(generatedHash == secondHash, "Raw data and received must be equal");

            secondParsedHash = rawHash;
            secondHash = 0;
        }

        if (firstHash == 0 && secondHash == 0) {
            currentStage = Stages.BOOST_SELECT;
            runAction(firstParsedHash, secondParsedHash);

            emit BoostSelectStageStarts(
                block.timestamp,
                roundCount
            );
        }
    }

    function useBoost(uint256 _boostIndex) public {
        require(currentStage == Stages.BOOST_SELECT, "Stage must be boost select");
        require(msg.sender == firstPlayer || msg.sender == secondPlayer, "Sender must be player");

        if (msg.sender == firstPlayer && firstBoost == 0) {
            firstBoost = _boostIndex;

            if (_boostIndex == 1) {
                firstPlayerStats.attack += 1;
            } else if (_boostIndex == 2) {
                firstPlayerStats.defence += 1;
            } else if (_boostIndex == 3) {
                firstPlayerStats.healAmount += 5;
            } else if (_boostIndex == 4) {
                firstPlayerStats.energyHealAmount += 1;
            }

            emit UserSpecificationsChanged(
                msg.sender,
                block.timestamp,
                firstPlayerStats.maxHp,
                firstPlayerStats.currentHp,
                firstPlayerStats.maxEnergy,
                firstPlayerStats.energy,
                firstPlayerStats.attack,
                firstPlayerStats.defence,
                firstPlayerStats.healAmount,
                firstPlayerStats.energyHealAmount
            );
        } else if (msg.sender == secondPlayer && secondBoost == 0) {
            secondBoost = _boostIndex;

            if (_boostIndex == 1) {
                secondPlayerStats.attack += 1;
            } else if (_boostIndex == 2) {
                secondPlayerStats.defence += 1;
            } else if (_boostIndex == 3) {
                secondPlayerStats.healAmount += 5;
            } else if (_boostIndex == 4) {
                secondPlayerStats.energyHealAmount += 1;
            }

            emit UserSpecificationsChanged(
                msg.sender,
                block.timestamp,
                secondPlayerStats.maxHp,
                secondPlayerStats.currentHp,
                secondPlayerStats.maxEnergy,
                secondPlayerStats.energy,
                secondPlayerStats.attack,
                secondPlayerStats.defence,
                secondPlayerStats.healAmount,
                secondPlayerStats.energyHealAmount
            );
        }

        if(firstBoost != 0 && secondBoost != 0) {
            roundHistory[roundCount][firstPlayer].push(firstBoost);
            roundHistory[roundCount][secondPlayer].push(secondBoost);

            firstBoost = 0;
            secondBoost = 0;
            currentStage = Stages.HASH_SENDING;
            roundCount++;
            roundStartedAt = block.timestamp;
            currentStepOwner++;

            emit HashSendingStageStarts(
                block.timestamp,
                roundCount
            );
        }
    }

    function runAction(
        string memory firstRawHash,
        string memory secondRawHash
    ) internal {
        for(uint256 i = 1; i < 4; i++) {
            // 1 - energy heal
            // 2 - attack
            // 3 - defence
            // 4 - heal
            string memory firstAction = getSlice(i, i, firstRawHash);
            string memory secondAction = getSlice(i, i, secondRawHash);

            if (currentStepOwner % 2 == 0) {
                // first player starts
                bool isFirstFinished = runFirstPlayerAction(firstAction, secondAction);

                if (isFirstFinished) {
                    return;
                }

                bool isSecondFinished = runSecondPlayerAction(firstAction, secondAction);

                if (isSecondFinished) {
                    return;
                }
            } else {
                // second player starts
                bool isSecondFinished = runSecondPlayerAction(firstAction, secondAction);

                if (isSecondFinished) {
                    return;
                }

                bool isFirstFinished = runFirstPlayerAction(firstAction, secondAction);

                if (isFirstFinished) {
                    return;
                }
            }
        }

        emit UserSpecificationsChanged(
            firstPlayer,
            block.timestamp,
            firstPlayerStats.maxHp,
            firstPlayerStats.currentHp,
            firstPlayerStats.maxEnergy,
            firstPlayerStats.energy,
            firstPlayerStats.attack,
            firstPlayerStats.defence,
            firstPlayerStats.healAmount,
            firstPlayerStats.energyHealAmount
        );
        emit UserSpecificationsChanged(
            secondPlayer,
            block.timestamp,
            secondPlayerStats.maxHp,
            secondPlayerStats.currentHp,
            secondPlayerStats.maxEnergy,
            secondPlayerStats.energy,
            secondPlayerStats.attack,
            secondPlayerStats.defence,
            secondPlayerStats.healAmount,
            secondPlayerStats.energyHealAmount
        );
    }

    function runFirstPlayerAction(
        string memory firstAction,
        string memory secondAction
    ) internal returns (bool) {
        if (compareStrings(firstAction, "1")) {
            roundHistory[roundCount][firstPlayer].push(1);
            firstPlayerStats.energy += firstPlayerStats.energyHealAmount;

            if (firstPlayerStats.energy > firstPlayerStats.maxEnergy) {
                firstPlayerStats.energy = firstPlayerStats.maxEnergy;
            }
        } else if (compareStrings(firstAction, "2") && firstPlayerStats.energy > 0) {
            roundHistory[roundCount][firstPlayer].push(2);
            firstPlayerStats.energy -= 1;

            uint256 attack = firstPlayerStats.attack;

            if (compareStrings(secondAction, "3")) {
                if(secondPlayerStats.defence > attack) {
                    attack = 0;
                } else {
                    attack -= secondPlayerStats.defence;
                }
            }

            if (secondPlayerStats.currentHp <= attack) {
                secondPlayerStats.currentHp = 0;
                setWinner(1);
                return true;
            } else {
                secondPlayerStats.currentHp -= attack;
            }
        } else if (compareStrings(firstAction, "3") && firstPlayerStats.energy > 0) {
            roundHistory[roundCount][firstPlayer].push(3);
            firstPlayerStats.energy -= 1;
        } else if (compareStrings(firstAction, "4") && firstPlayerStats.energy > 0) {
            roundHistory[roundCount][firstPlayer].push(4);
            firstPlayerStats.energy -= 1;

            firstPlayerStats.currentHp += firstPlayerStats.healAmount;

            if (firstPlayerStats.currentHp > firstPlayerStats.maxHp) {
                firstPlayerStats.currentHp = firstPlayerStats.maxHp;
            }
        }

        return false;
    }

    function runSecondPlayerAction(
        string memory firstAction,
        string memory secondAction
    ) internal returns (bool) {
        if (compareStrings(secondAction, "1")) {
            roundHistory[roundCount][secondPlayer].push(1);
            secondPlayerStats.energy += secondPlayerStats.energyHealAmount;

            if (secondPlayerStats.energy > secondPlayerStats.maxEnergy) {
                secondPlayerStats.energy = secondPlayerStats.maxEnergy;
            }
        } else if (compareStrings(secondAction, "2") && secondPlayerStats.energy > 0) {
            roundHistory[roundCount][secondPlayer].push(2);
            secondPlayerStats.energy -= 1;

            uint256 attack = secondPlayerStats.attack;

            if (compareStrings(firstAction, "3")) {
                if(firstPlayerStats.defence > attack) {
                    attack = 0;
                } else {
                    attack -= firstPlayerStats.defence;
                }
            }

            if (firstPlayerStats.currentHp <= attack) {
                firstPlayerStats.currentHp = 0;
                setWinner(2);
                return true;
            } else {
                firstPlayerStats.currentHp -= attack;
            }
        } else if (compareStrings(secondAction, "3") && secondPlayerStats.energy > 0) {
            roundHistory[roundCount][secondPlayer].push(3);
            secondPlayerStats.energy -= 1;
        } else if (compareStrings(secondAction, "4") && secondPlayerStats.energy > 0) {
            roundHistory[roundCount][secondPlayer].push(4);
            secondPlayerStats.energy -= 1;

            secondPlayerStats.currentHp += secondPlayerStats.healAmount;

            if (secondPlayerStats.currentHp > secondPlayerStats.maxHp) {
                secondPlayerStats.currentHp = secondPlayerStats.maxHp;
            }
        }

        return false;
    }

    function setWinner(uint256 _winnerId) internal {
        if (_winnerId == 1) {
            winner = firstPlayer;
        } else {
            winner = secondPlayer;
        }

        lobbyContract.endGame(winner);

        currentStage = Stages.FINISHED;

        emit FinishStageStarts(
            winner,
            block.timestamp
        );
    }

    function getSlice(uint256 begin, uint256 end, string memory text) internal pure returns (string memory) {
        bytes memory a = new bytes(end - begin + 1);

        for(uint i = 0; i <= end - begin; i++) {
            a[i] = bytes(text)[i + begin - 1];
        }

        return string(a);
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}
