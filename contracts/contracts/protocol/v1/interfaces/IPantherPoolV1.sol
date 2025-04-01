// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { SnarkProof } from "../../../common/Types.sol";
import { LockData } from "../../../common/Types.sol";

interface IPantherPoolV1 {
    function accountPrp(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes memory privateMessages
    ) external returns (uint256 utxoBusQueuePos);

    function createZzkpUtxoAndSpendPrpUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 zkpAmountOutRounded,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external returns (uint256);

    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        address zkpPayer,
        uint96 paymasterCompensation,
        bytes memory privateMessages
    ) external returns (uint256);

    function main(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint8 tokenType,
        uint96 paymasterCompensation,
        bytes memory privateMessages
    ) external payable returns (uint256);

    function unlockAssetFromVault(LockData calldata data) external;
}
