// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../merkleTrees/BinaryUpdatableMerkleTree.sol";

import { PoseidonT3 } from "../../crypto/Poseidon.sol";
import { FIELD_SIZE } from "../../crypto/SnarkConstants.sol";

abstract contract BlacklistedZAccountIdsTree is BinaryUpdatableMerkleTree {
    // solhint-disable const-name-snakecase

    uint256 internal constant iZACCOUNT_ID_FLAG_POS_MASK = 0xFF;

    uint256 internal constant zACCOUNT_ID_JUMP_COUNT = 4;

    uint256 internal constant zACCOUNT_ID_ZERO = 0;
    uint256 internal constant zACCOUNT_ID_MAX_RANGE =
        (2**8) - zACCOUNT_ID_JUMP_COUNT;

    // solhint-enable const-name-snakecase

    function _getZAccountFlagAndLeafIndexes(uint24 zAccountId)
        internal
        pure
        returns (uint256 flagIndex, uint256 leafIndex)
    {
        // getting position which is between 1 and 252
        uint256 flagPos = zAccountId & iZACCOUNT_ID_FLAG_POS_MASK;

        require(
            flagPos > zACCOUNT_ID_ZERO && flagPos <= zACCOUNT_ID_MAX_RANGE,
            "ZAR: invalid flag index"
        );

        flagIndex = flagPos - 1;
        // getting the 16 MSB from uint24
        leafIndex = zAccountId >> 8;
    }

    function _addBlacklistZAccountId(
        uint24 zAccountId,
        bytes32 leaf,
        bytes32[] memory proofSiblings
    ) internal {
        (uint256 flagIndex, uint256 leafIndex) = _getZAccountFlagAndLeafIndexes(
            zAccountId
        );

        uint256 newLeaf = uint256(leaf) | (1 << flagIndex);

        update(leaf, bytes32(newLeaf), leafIndex, proofSiblings);
    }

    function _removeBlacklistZAccountId(
        uint24 zAccountId,
        bytes32 leaf,
        bytes32[] memory proofSiblings
    ) internal {
        (uint256 flagIndex, uint256 leafIndex) = _getZAccountFlagAndLeafIndexes(
            zAccountId
        );

        uint256 newLeaf = uint256(leaf) & ~(1 << flagIndex);

        update(leaf, bytes32(newLeaf), leafIndex, proofSiblings);
    }

    function hash(bytes32 left, bytes32 right)
        internal
        pure
        override
        returns (bytes32)
    {
        require(
            uint256(left) < FIELD_SIZE && uint256(right) < FIELD_SIZE,
            "ZAR:TOO_LARGE_LEAF_INPUT"
        );
        return PoseidonT3.poseidon([left, right]);
    }
}
