// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./../Ownable.sol";

contract SharedData is Ownable {
    struct Stats {
        uint256 hp;
        uint256 energy;
        uint256 attack;
        uint256 defence;
    }

    struct CurrentStats {
        uint256 maxHp;
        uint256 currentHp;
        uint256 maxEnergy;
        uint256 energy;
        uint256 attack;
        uint256 defence;
        uint256 healAmount;
        uint256 energyHealAmount;
    }

    enum Statuses {
        PREPARATION,
        IN_PROGRESS,
        FINISHED
    }

    enum Stages {
        PREPARATION,
        HASH_SENDING,
        HASH_APPROVING,
        BOOST_SELECT,
        FINISHED
    }

    Stats public defaultStats = Stats(100, 10, 10, 9);
    uint256 public HEAL_AMOUNT = 15;
    uint256 public ENERGY_HEAL_AMOUNT = 2;
    uint256 public ADMIN_PERCENTAGE = 5;
    mapping(address => uint256) public percentages;
    address[] public admins;

    event AdminAddressAdded(
        address newAddress,
        uint256 percentage
    );
    event AdminAddressRemoved(
        address oldAddress
    );
    event AdminPersonalPercentageChanged(
        address admin,
        uint256 newPercentage
    );
    event AdminPercentageChanged(
        uint256 newPercentage
    );
    event HealAmountChanged(
        uint256 newPercentage
    );
    event EnergyHealAmountChanged(
        uint256 newPercentage
    );

    function changeHeal(uint256 _amount) public onlyOwner {
        HEAL_AMOUNT = _amount;

        emit HealAmountChanged(
            _amount
        );
    }

    function changeEnergyHeal(uint256 _amount) public onlyOwner {
        ENERGY_HEAL_AMOUNT = _amount;

        emit EnergyHealAmountChanged(
            _amount
        );
    }

    // percentage in 0.x% for example 5 is 0.5%
    function changeAdminPercentage(uint256 _amount) public onlyOwner {
        ADMIN_PERCENTAGE = _amount;

        emit AdminPercentageChanged(
            _amount
        );
    }

    function addAdmin(address _admin, uint256 _percentage) public onlyOwner {
        require(percentages[_admin] == 0, "Admin exists");

        admins.push(_admin);
        percentages[_admin] = _percentage;

        emit AdminAddressAdded(
            _admin,
            _percentage
        );
    }

    function changePersonalPercentage(
        address _admin,
        uint256 _percentage
    ) public onlyOwner {
        percentages[_admin] = _percentage;

        emit AdminPersonalPercentageChanged(
            _admin,
            _percentage
        );
    }

    function deleteAdmin(address _removedAdmin) public onlyOwner {
        uint256 found = 0;
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == _removedAdmin) {
                found = i;
            }
        }

        for (uint256 i = found; i < admins.length - 1; i++) {
            admins[i] = admins[i + 1];
        }

        admins.pop();

        percentages[_removedAdmin] = 0;

        emit AdminAddressRemoved(_removedAdmin);
    }
}
