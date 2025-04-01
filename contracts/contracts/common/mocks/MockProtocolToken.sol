// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable one-contract-per-file
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../ImmutableOwnable.sol";

contract MockZkp is ERC20, ImmutableOwnable {
    constructor(
        address _owner
    ) ERC20("Mock-ZKP", "ZKP") ImmutableOwnable(_owner) {}

    function mint(
        address _account,
        uint256 _amount
    ) public onlyOwner returns (bool) {
        _mint(_account, _amount);
        return true;
    }
}

contract MockPZkp is ERC20, ImmutableOwnable {
    constructor(
        address _owner
    ) ERC20("Mock-PZKP", "PZKP") ImmutableOwnable(_owner) {}

    function mint(
        address _account,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        _mint(_account, _amount);
        return true;
    }

    function deposit(
        address user,
        bytes calldata depositData
    ) external onlyOwner {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}
