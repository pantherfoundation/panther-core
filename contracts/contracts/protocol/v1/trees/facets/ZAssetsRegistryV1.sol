// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable no-unused-vars
pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ZAssetsRegistryStorageGap.sol";

import "./staticTrees/StaticRootUpdater.sol";

import "../../diamond/utils/Ownable.sol";
import "../utils/merkleTrees/BinaryUpdatableTree.sol";
import { SIXTEEN_LEVEL_EMPTY_TREE_ROOT, ZERO_VALUE } from "../utils/zeroTrees/Constants.sol";
import { ZASSET_STATIC_LEAF_INDEX } from "../utils/Constants.sol";

import "../../../../common/crypto/PoseidonHashers.sol";
import { ERC20_TOKEN_TYPE, NATIVE_TOKEN_TYPE, ERC721_TOKEN_TYPE } from "../../../../common/Constants.sol";

import "../../../../common/UtilsLib.sol";

/**
 * @title ZAssetsRegistryV1
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of assets (tokens) supported by the Panther
 * Protocol Multi-Asset Shielded Pool (aka "MASP")
 */

abstract contract ZAssetsRegistryV1 is
    StaticRootUpdater,
    Ownable,
    BinaryUpdatableTree
{
    using UtilsLib for address;

    // the next leaf index
    uint32 public totalLeavesInserted;

    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    struct ZAsset {
        address token;
        uint32 tokenId;
        uint8 networkId;
        uint32 offset;
        uint16 weight;
        uint8 scaleFactor;
    }

    mapping(uint256 => ZAsset) public zAssets;

    event ZAssetRootUpdated(bytes32 newRoot, ZAsset zAsset);

    constructor(address self) StaticRootUpdater(self) {}

    function getZAssetsRoot() external view returns (bytes32) {
        return _currentRoot == bytes32(0) ? zeroRoot() : _currentRoot;
    }

    function addZAsset(
        uint8 tokenType,
        ZAsset calldata zAsset,
        bytes32[] calldata proofSiblings
    ) external onlyOwner {
        uint32 _leafIndex = totalLeavesInserted;

        _sanitizeZAssetParms(tokenType, zAsset);

        uint64 zAssetId = _getZAssetId(_leafIndex);
        bytes32 newLeaf = _generateLeaf(zAssetId, zAsset);

        bytes32 zAssetsTreeRoot = update(
            _currentRoot,
            ZERO_VALUE,
            newLeaf,
            _leafIndex,
            proofSiblings
        );

        totalLeavesInserted = _leafIndex + 1;

        _updateZAsset(_leafIndex, zAsset);
        _updateZAssetsRegistryAndStaticRoots(zAssetsTreeRoot, zAsset);
    }

    function updateZAssetWeightAndScale(
        uint32 leafIndex,
        uint16 newWeight,
        uint8 newScaleFactor,
        bytes32[] calldata proofSiblings
    ) external onlyOwner {
        ZAsset memory zAsset = zAssets[leafIndex];

        uint64 zAssetId = _getZAssetId(leafIndex);

        bytes32 currentLeaf = _generateLeaf(zAssetId, zAsset);

        zAsset.weight = newWeight;
        zAsset.scaleFactor = newScaleFactor;
        bytes32 newLeaf = _generateLeaf(zAssetId, zAsset);

        bytes32 zAssetsTreeRoot = update(
            _currentRoot,
            currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings
        );

        _updateZAsset(leafIndex, zAsset);
        _updateZAssetsRegistryAndStaticRoots(zAssetsTreeRoot, zAsset);
    }

    function _getZAssetId(uint64 leafIndex) private pure returns (uint64) {
        return leafIndex << 32;
    }

    function _updateZAsset(uint256 leafIndex, ZAsset memory zAsset) private {
        zAssets[leafIndex] = zAsset;
    }

    function _sanitizeZAssetParms(
        uint8 tokenType,
        ZAsset calldata _zAsset
    ) private pure {
        if (tokenType == ERC20_TOKEN_TYPE) _sanitizeErc20Params(_zAsset);
        if (tokenType == NATIVE_TOKEN_TYPE) _sanitizeNativeParams(_zAsset);
        if (tokenType == ERC721_TOKEN_TYPE) _sanitizeErc721Params(_zAsset);
    }

    function _sanitizeErc20Params(ZAsset calldata _zAsset) private pure {
        _checkNonZeroAddress(_zAsset.token);
        _checkZeroTokenID(_zAsset.tokenId);
        _checkZeroOffset(_zAsset.offset);
    }

    function _sanitizeNativeParams(ZAsset calldata _zAsset) private pure {
        _checkZeroAddress(_zAsset.token);
        _checkZeroTokenID(_zAsset.tokenId);
        _checkZeroOffset(_zAsset.offset);
    }

    function _sanitizeErc721Params(ZAsset calldata _zAsset) private pure {
        _checkNonZeroAddress(_zAsset.token);

        //TODO check the tokenID
    }

    function _checkNonZeroAddress(address token) private pure {
        require(token != address(0), "ZAR: zero token address");
    }

    function _checkZeroAddress(address token) private pure {
        require(token == address(0), "ZAR: non-zero token address");
    }

    function _checkZeroTokenID(uint256 tokenId) private pure {
        require(tokenId == 0, "ZAR: non-zero token id");
    }

    function _checkZeroOffset(uint256 offset) private pure {
        require(offset == 0, "ZAR: non-zero offset");
    }

    function _generateLeaf(
        uint256 zAssetId,
        ZAsset memory zAsset
    ) private pure returns (bytes32) {
        uint256 zAssetScale = 10 ** zAsset.scaleFactor;
        // return
        //     PoseidonHashers.poseidonT8(
        //         [
        //             bytes32(zAssetId),
        //             bytes32(uint256(uint160(zAsset.token))),
        //             bytes32(uint256(zAsset.tokenId)),
        //             bytes32(uint256(zAsset.networkId)),
        //             bytes32(uint256(zAsset.offset)),
        //             bytes32(uint256(zAsset.weight)),
        //             bytes32(zAssetScale)
        //         ]
        //     );
    }

    //@dev returns the root of tree with depth 16 where each leaf is ZERO_VALUE
    function zeroRoot() internal pure override returns (bytes32) {
        return SIXTEEN_LEVEL_EMPTY_TREE_ROOT;
    }

    function hash(
        bytes32[2] memory input
    ) internal pure override returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }

    function _updateZAssetsRegistryAndStaticRoots(
        bytes32 zAssetsTreeRoot,
        ZAsset memory _zAsset
    ) private {
        _currentRoot = zAssetsTreeRoot;
        _updateStaticRoot(zAssetsTreeRoot, ZASSET_STATIC_LEAF_INDEX);

        emit ZAssetRootUpdated(zAssetsTreeRoot, _zAsset);
    }
}
