// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity ^0.8.19;

import "../interfaces/IVaultV1.sol";
import "../../../common/ImmutableOwnable.sol";
import { LockData } from "../../../common/Types.sol";

interface IMockPantherPoolV1 {
    function unlockAssetFromVault(LockData calldata data) external;
}

// slither-disable shadowing-state
// slither-disable unused-state
contract MockPantherPoolV1 is IMockPantherPoolV1, ImmutableOwnable {
    // slither-disable-next-line shadowing-state unused-state
    uint256[500] private __gap;

    address public immutable VAULT;

    mapping(address => bool) public vaultAssetUnlockers;

    constructor(address vault, address _owner) ImmutableOwnable(_owner) {
        require(vault != address(0), "init: zero address");
        VAULT = vault;
    }

    function updateVaultAssetUnlocker(
        address _unlocker,
        bool _status
    ) external onlyOwner {
        vaultAssetUnlockers[_unlocker] = _status;
    }

    function unlockAssetFromVault(LockData calldata data) external {
        require(vaultAssetUnlockers[msg.sender], "mockPoolV1: unauthorized");

        IVaultV1(VAULT).unlockAsset(data);
    }
}
