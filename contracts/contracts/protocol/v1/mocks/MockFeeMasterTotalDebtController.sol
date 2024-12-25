// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar

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
