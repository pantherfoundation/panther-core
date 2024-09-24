// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

pragma solidity ^0.8.19;

import "../../../../common/UtilsLib.sol";

string constant ERR_INVALID_CREATE_TIME = "PIG:E1";
string constant ERR_INVALID_CHAIN_ID = "PIG:E2";
string constant ERR_INVALID_SPEND_TIME = "PIG:E3";
string constant ERR_INVALID_EXTRA_INPUT_HASH = "PIG:E4";
string constant ERR_INVALID_PANTHER_TREES_ROOT = "PIG:E5";
string constant ERR_INVALID_VAULT_ADDRESS = "PIG:E6";

import { FIELD_SIZE } from "../../../../common/crypto/SnarkConstants.sol";

// this library methods to validate public inputs
library PublicInputGuard {
    using UtilsLib for uint256;

    function validateNonZero(
        uint256 value,
        string memory errMsg
    ) internal pure {
        require(value != 0, errMsg);
    }

    function validateChainId(uint256 zNetworkChainId) internal view {
        require(zNetworkChainId == block.chainid, ERR_INVALID_CHAIN_ID);
    }

    function validateVaultAddress(address vault, uint256 input) internal pure {
        require(vault == input.safeAddress(), ERR_INVALID_VAULT_ADDRESS);
    }

    function validateCreationTime(
        uint256 creationTime,
        uint256 maxBlockTimeOffset
    ) internal view {
        // Must be less than 32 bits and NOT in the past
        uint32 creationTimeSafe32 = creationTime.safe32();

        require(
            creationTimeSafe32 >= block.timestamp &&
                (maxBlockTimeOffset == 0 ||
                    creationTimeSafe32 - block.timestamp <= maxBlockTimeOffset),
            ERR_INVALID_CREATE_TIME
        );
    }

    function validateSpendTime(
        uint256 spendTime,
        uint256 maxBlockTimeOffset
    ) internal view {
        // Must be less than 32 bits and NOT in the past
        uint32 spendTimeSafe32 = spendTime.safe32();

        require(
            spendTimeSafe32 <= block.timestamp &&
                (maxBlockTimeOffset == 0 ||
                    block.timestamp - spendTimeSafe32 <= maxBlockTimeOffset),
            ERR_INVALID_SPEND_TIME
        );
    }

    function validateExtraInputHash(
        uint256 extraInputsHash,
        bytes memory extraInp
    ) internal pure {
        require(
            extraInputsHash == uint256(keccak256(extraInp)) % FIELD_SIZE,
            ERR_INVALID_EXTRA_INPUT_HASH
        );
    }
}
