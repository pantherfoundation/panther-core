// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
// slither-disable-next-line solc-version
pragma solidity ^0.8.16;

// solhint-disable var-name-mixedcase

// The "prp grant type" for the "release and bridge" ZKPs
// bytes4(keccak256("ZKP_RELEASE_AND_BRIDGE"))
bytes4 constant ZKP_RELEASE_AND_BRIDGE_PRP_GRANT_TYPE = 0x02c37d4a;

// The "prp grant type" for swapping zkp for fee token
// bytes4(keccak256("ZKP_SWAP_FOR_FEE_TOKEN"))
bytes4 constant ZKP_SWAP_FOR_FEE_TOKEN_PRP_GRANT_TYPE = 0xacabdeb3;

// The "prp grant type" for the transferring ZKP to treasury and PRP converter
// bytes4(keccak256("ZKP_TRANSFER_TO_TREASURY_AND_PRP_CONVERTER"))
bytes4 constant ZKP_TRANSFER_TO_TREASURY_AND_PRP_CONVERTER_PRP_GRANT_TYPE = 0xe96177c4;

// solhint-enable var-name-mixedcase
