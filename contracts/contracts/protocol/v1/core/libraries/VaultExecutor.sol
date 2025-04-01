// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../interfaces/IVaultV1.sol";

// Vault is a Trusted contract - no reentrancy guard needed
library VaultExecutor {
    function lockAsset(address vault, LockData memory lockData) internal {
        try
            IVaultV1(vault).lockAsset{ value: msg.value }(lockData)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function lockAssetWithSalt(
        address vault,
        SaltedLockData memory slData
    ) internal {
        try
            IVaultV1(vault).lockAssetWithSalt{ value: msg.value }(slData)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function unlockAsset(address vault, LockData memory lockData) internal {
        try
            IVaultV1(vault).unlockAsset(lockData)
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
    }
}
