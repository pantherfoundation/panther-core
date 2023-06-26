// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import { SnarkProof } from "../../common/Types.sol";

interface IPantherPoolV1 {
    function createUtxo(
        uint256[14] calldata inputs,
        uint256 secret,
        SnarkProof calldata proof
    ) external view returns (bool);
}
