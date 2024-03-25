// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import { SnarkProof } from "../../../common/Types.sol";
import { LockData } from "../../../common/Types.sol";

interface IPantherPoolV1 {
    function accountPrp(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint256 cachedForestRootIndex,
        uint96 paymasterCompensation,
        bytes memory privateMessages
    ) external returns (uint256 utxoBusQueuePos);

    function createZzkpUtxoAndSpendPrpUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint256 cachedForestRootIndex,
        uint256 zkpAmountOutRounded,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external returns (uint256);

    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint256 cachedForestRootIndex,
        address zkpPayer,
        uint96 paymasterCompensation,
        bytes memory privateMessages
    ) external returns (uint256);

    function main(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint256 cachedForestRootIndex,
        uint8 tokenType,
        uint96 paymasterCompensation,
        bytes memory privateMessages
    ) external payable returns (uint256);

    function unlockAssetFromVault(LockData calldata data) external;
}
