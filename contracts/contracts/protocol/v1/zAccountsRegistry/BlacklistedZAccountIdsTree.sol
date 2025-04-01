// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../pantherForest/interfaces/ITreeRootGetter.sol";

import "../pantherForest/merkleTrees/BinaryUpdatableTree.sol";
import "../errMsgs/ZAccountsRegistryErrMsgs.sol";

import "../../../common/crypto/PoseidonHashers.sol";

abstract contract BlacklistedZAccountIdsTree is
    BinaryUpdatableTree,
    ITreeRootGetter
{
    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    function getRoot() external view returns (bytes32) {
        return _currentRoot == bytes32(0) ? zeroRoot() : _currentRoot;
    }

    function _getZAccountFlagAndLeafIndexes(
        uint24 zAccountId
    ) internal pure returns (uint256 flagIndex, uint256 leafIndex) {
        // getting index which is between 0 and 253
        flagIndex = zAccountId & 0xFF;

        require(flagIndex < 254, ERR_INVALID_ZACCOUNT_FLAG_POSITION);

        // getting the 16 MSB from uint24
        leafIndex = zAccountId >> 8;
    }

    function _addZAccountIdToBlacklist(
        uint24 zAccountId,
        bytes32 leaf,
        bytes32[] memory proofSiblings
    ) internal returns (bytes32 _updatedRoot) {
        (uint256 flagIndex, uint256 leafIndex) = _getZAccountFlagAndLeafIndexes(
            zAccountId
        );

        uint256 newLeaf = uint256(leaf) | (1 << flagIndex);

        _updatedRoot = update(
            _currentRoot,
            leaf,
            bytes32(newLeaf),
            leafIndex,
            proofSiblings
        );

        _currentRoot = _updatedRoot;
    }

    function _removeZAccountIdFromBlacklist(
        uint24 zAccountId,
        bytes32 leaf,
        bytes32[] memory proofSiblings
    ) internal returns (bytes32 _updatedRoot) {
        (uint256 flagIndex, uint256 leafIndex) = _getZAccountFlagAndLeafIndexes(
            zAccountId
        );

        uint256 newLeaf = uint256(leaf) & ~(1 << flagIndex);

        _updatedRoot = update(
            _currentRoot,
            leaf,
            bytes32(newLeaf),
            leafIndex,
            proofSiblings
        );

        _currentRoot = _updatedRoot;
    }

    function hash(
        bytes32[2] memory input
    ) internal pure override returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }

    //@dev returns the root of tree with depth 16 where each leaf is 0
    function zeroRoot() internal pure override returns (bytes32) {
        /**
        '0x0000000000000000000000000000000000000000000000000000000000000000'   Level 0
        '0x2098f5fb9e239eab3ceac3f27b81e481dc3124d55ffed523a839ee8446b64864'   Level 1
        '0x1069673dcdb12263df301a6ff584a7ec261a44cb9dc68df067a4774460b1f1e1'   Level 2
        '0x18f43331537ee2af2e3d758d50f72106467c6eea50371dd528d57eb2b856d238'   Level 3
        '0x07f9d837cb17b0d36320ffe93ba52345f1b728571a568265caac97559dbc952a'   Level 4
        '0x2b94cf5e8746b3f5c9631f4c5df32907a699c58c94b2ad4d7b5cec1639183f55'   Level 5
        '0x2dee93c5a666459646ea7d22cca9e1bcfed71e6951b953611d11dda32ea09d78'   Level 6
        '0x078295e5a22b84e982cf601eb639597b8b0515a88cb5ac7fa8a4aabe3c87349d'   Level 7
        '0x2fa5e5f18f6027a6501bec864564472a616b2e274a41211a444cbe3a99f3cc61'   Level 8
        '0x0e884376d0d8fd21ecb780389e941f66e45e7acce3e228ab3e2156a614fcd747'   Level 9
        '0x1b7201da72494f1e28717ad1a52eb469f95892f957713533de6175e5da190af2'   Level 10
        '0x1f8d8822725e36385200c0b201249819a6e6e1e4650808b5bebc6bface7d7636'   Level 11
        '0x2c5d82f66c914bafb9701589ba8cfcfb6162b0a12acf88a8d0879a0471b5f85a'   Level 12
        '0x14c54148a0940bb820957f5adf3fa1134ef5c4aaa113f4646458f270e0bfbfd0'   Level 13
        '0x190d33b12f986f961e10c0ee44d8b9af11be25588cad89d416118e4bf4ebe80c'   Level 14
        '0x22f98aa9ce704152ac17354914ad73ed1167ae6596af510aa5b3649325e06c92'   Level 15
         */
        return
            bytes32(
                uint256(
                    0x2a7c7c9b6ce5880b9f6f228d72bf6a575a526f29c66ecceef8b753d38bba7323
                )
            );
    }
}
