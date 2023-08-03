// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023s Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../interfaces/IVault.sol";
import "../../common/ImmutableOwnable.sol";
import { LockData } from "../../common/Types.sol";
import "../pantherForest/PantherForest.sol";

interface IMockPantherPoolV1 {
    function unlockAssetFromVault(LockData calldata data) external;
}

// solhint-disable var-name-mixedcase
// slither-disable shadowing-state
// slither-disable unused-state
contract MockPantherPoolV1 is PantherForest, IMockPantherPoolV1, ImmutableOwnable {
    // slither-disable-next-line shadowing-state unused-state
    uint256[500 - 26] private __gap;

    address public immutable VAULT;

    mapping(address => bool) public vaultAssetUnlockers;

    constructor(address vault, address _owner) ImmutableOwnable(_owner) {
        require(vault != address(0), "init: zero address");
        VAULT = vault;
    }

    function updateVaultAssetUnlocker(address _unlocker, bool _status)
        external
        onlyOwner
    {
        vaultAssetUnlockers[_unlocker] = _status;
    }

    function unlockAssetFromVault(LockData calldata data) external {
        require(vaultAssetUnlockers[msg.sender], "mockPoolV1: unauthorized");

        IVault(VAULT).unlockAsset(data);
    }
}
