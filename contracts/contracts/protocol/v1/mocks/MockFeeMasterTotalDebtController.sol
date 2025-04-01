// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

pragma solidity ^0.8.19;

import "../core/facets/FeeMasterTotalDebtController.sol";

contract MockFeeMasterTotalDebtController is FeeMasterTotalDebtController {
    constructor(
        address vault,
        address feeMaster
    ) FeeMasterTotalDebtController(vault, feeMaster) {}

    function setFeeMasterDebt(address account, uint256 amount) external {
        feeMasterDebt[account] = amount; // Override the value
    }

    function getVaultAddr() external view returns (address _vault) {
        return VAULT;
    }

    function getFeeMasterAddr() external view returns (address _feeMaster) {
        return FEE_MASTER;
    }
}
