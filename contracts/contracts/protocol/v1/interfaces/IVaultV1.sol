// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { LockData, SaltedLockData } from "../../../common/Types.sol";
import { IEthEscrow } from "./IEthEscrow.sol";

interface IVaultV1 is IEthEscrow {
    /***
      @notice Transfers token from account defined by `salt` to this contract.
      Only the owner may call.
      @dev "Salt" protects against front-runners (if used properly). Refer to
      PullWithSaltHelper for details.
      @dev The caller (owner) MUST guard against the re-entrance attack.
      If an attacker (via a malicious token contract this contract calls) enters
      this function directly, it reverts since `msg.sender` won't be `owner`.
     */
    function lockAssetWithSalt(SaltedLockData calldata slData) external payable;

    /***
      @notice Transfers token from the given account to this contract
      @dev It does not use "salt" and is prune to front-running attacks.
      May only be used if other means/contracts provide the adequate protection.
      @dev The comment above on the re-entrance is applicable for this function.
     */
    function lockAsset(LockData calldata lData) external;

    /***
      @notice Transfers token from this contract to the given account.
      Only the owner may call.
      @dev The comment above on the re-entrance is applicable for this function.
     */
    function unlockAsset(LockData calldata lData) external;

    event Locked(LockData data);
    event Unlocked(LockData data);
    event SaltUsed(bytes32 salt);
}
