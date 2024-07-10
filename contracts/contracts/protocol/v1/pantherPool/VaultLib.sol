// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/IVaultV1.sol";

// Vault is a Trusted contract - no reentrancy guard needed
library VaultLib {
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
