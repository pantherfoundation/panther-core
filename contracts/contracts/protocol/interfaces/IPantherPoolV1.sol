// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { SnarkProof } from "../../common/Types.sol";
import { LockData } from "../../common/Types.sol";

interface IPantherPoolV1 {
    function accountPrp(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        bytes memory privateMessages,
        uint256 cachedForestRootIndex
    ) external returns (uint256 utxoBusQueuePos);

    function createZzkpUtxoAndSpendPrpUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        bytes memory privateMessages,
        uint256 zkpAmountRounded,
        uint256 cachedForestRootIndex
    ) external returns (uint256);

    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        address zkpPayer,
        bytes memory secretMessage,
        uint256 cachedForestRootIndex
    ) external returns (uint256);

    function unlockAssetFromVault(LockData calldata data) external;
}
