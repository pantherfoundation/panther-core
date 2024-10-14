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
import { ERC20_TOKEN_TYPE, NATIVE_TOKEN_TYPE, ERC721_TOKEN_TYPE, ERC1155_TOKEN_TYPE } from "../../../../common/Constants.sol";
import { FIELD_SIZE } from "../../../../common/crypto/SnarkConstants.sol";

import "../libraries/ZAssetEncodingUtils.sol";

/**
 * @title ZAssetsRegistryV1
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of assets (tokens) supported by the Panther
 * Protocol Multi-Asset Shielded Pool (aka "MASP")
 */

contract ZAssetsRegistryV1 is
    AppStorage,
    ZAssetsRegistryStorageGap,
    StaticRootUpdater,
    Ownable,
    BinaryUpdatableTree
{
    using UtilsLib for address;
    using ZAssetEncodingUtils for uint32;
    using ZAssetEncodingUtils for address;

    uint8 private constant UNDEFINED_NETWORK_ID = 63;
    uint256 private constant TARGET_WEIGHTED_AMOUNT_PER_USD = 1e8;

    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    // the next leaf index
    uint32 private totalLeavesInserted;

    address public weightController;

    struct ZAssetInnerParams {
        address token;
        uint64 batchId;
        uint32 startTokenId;
        uint32 tokenIdsRangeSize;
        uint8 scaleFactor;
        uint8 networkId;
        uint8 tokenType;
    }

    struct WeightMetrics {
        uint48 updatedWeight;
        uint16 scUsdPrice;
        uint8 zAssetDecimal;
        uint64 zAssetScale;
    }

    // zAsset key to inner hash
    mapping(uint64 => bytes32) private zAssetsInnerHash;

    // zAsset key to network ID
    mapping(uint64 => uint8) private previousZAssetsNetwork;

    event ZAssetRootUpdated(
        bytes32 newRoot,
        bytes32 zAssetInnerHash,
        uint48 weight
    );
    event WeightControllerUpdated(address weightController);

    constructor(address self) StaticRootUpdater(self) {}

    function getZAssetsRoot() external view returns (bytes32) {
        return _currentRoot == bytes32(0) ? zeroRoot() : _currentRoot;
    }

    function getZAssetKey(
        uint64 batchId,
        uint32 leafIndex
    ) public pure returns (uint64) {
        // the 32 LSB of batchId is 0
        return batchId | leafIndex;
    }

    function isZAssetEnabled(uint64 zAssetKey) public view returns (bool) {
        uint8 _previousZAssetNetwork = previousZAssetsNetwork[zAssetKey];
        return _previousZAssetNetwork == UNDEFINED_NETWORK_ID;
    }

    function updateWeightController(
        address _weightController
    ) external onlyOwner {
        weightController = _weightController;

        emit WeightControllerUpdated(_weightController);
    }

    function addZAsset(
        ZAssetInnerParams calldata zAssetInnerParams,
        uint48 weight,
        bytes32[] calldata proofSiblings
    ) external onlyOwner {
        _sanitizeZAssetParms(zAssetInnerParams);

        uint64 _batchId = zAssetInnerParams.batchId;

        uint32 _leafIndex = totalLeavesInserted;
        uint64 _zAssetKey = getZAssetKey(_batchId, _leafIndex);

        bytes32 _zAssetInnerHash = _generateZAssetInnerHash(zAssetInnerParams);

        require(!_isZAssetExist(_zAssetKey), "ZAR: already added");

        bytes32 _newLeaf = _generateLeaf(_zAssetInnerHash, weight);

        bytes32 zAssetsTreeRoot = update(
            _currentRoot,
            ZERO_VALUE,
            _newLeaf,
            _leafIndex,
            proofSiblings
        );

        totalLeavesInserted = _leafIndex + 1;

        _updatePreviousZAssetsNetwork(_zAssetKey, UNDEFINED_NETWORK_ID);

        _updateZAssetsInnerHash(_zAssetKey, _zAssetInnerHash);

        _updateZAssetsRegistryAndStaticRoots(
            zAssetsTreeRoot,
            _zAssetInnerHash,
            weight
        );
    }

    function updateZAssetWeight(
        WeightMetrics calldata weightMetrics,
        uint64 batchId,
        uint32 leafIndex,
        bytes32 currentLeaf,
        bytes32[] calldata proofSiblings
    ) external {
        require(msg.sender == weightController, "only weight controller");
        _checkUpdatedWeight(weightMetrics);

        uint64 zAssetKey = getZAssetKey(batchId, leafIndex);
        require(isZAssetEnabled(zAssetKey), "ZAR: disabled zAsset");

        bytes32 zAssetInnerHash = zAssetsInnerHash[zAssetKey];

        bytes32 newLeaf = _generateLeaf(
            zAssetInnerHash,
            weightMetrics.updatedWeight
        );

        bytes32 zAssetsTreeRoot = update(
            _currentRoot,
            currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings
        );

        _updateZAssetsRegistryAndStaticRoots(
            zAssetsTreeRoot,
            zAssetInnerHash,
            weightMetrics.updatedWeight
        );
    }

    function toggleZAssetStatus(
        ZAssetInnerParams memory currentZAssetInnerParams,
        uint48 weight,
        bool isEnabled,
        uint32 leafIndex,
        bytes32[] calldata proofSiblings
    ) external onlyOwner {
        uint64 _batchId = currentZAssetInnerParams.batchId;
        uint64 _zAssetKey = getZAssetKey(_batchId, leafIndex);

        bytes32 _currentZAssetInnerHash = _generateZAssetInnerHash(
            currentZAssetInnerParams
        );
        bytes32 _currentLeaf = _generateLeaf(_currentZAssetInnerHash, weight);

        if (isEnabled) {
            require(!isZAssetEnabled(_zAssetKey), "ZAR: already enabled");

            currentZAssetInnerParams.networkId = previousZAssetsNetwork[
                _zAssetKey
            ];
            _updatePreviousZAssetsNetwork(_zAssetKey, UNDEFINED_NETWORK_ID);
        } else {
            require(isZAssetEnabled(_zAssetKey), "ZAR: already disabled");

            currentZAssetInnerParams.networkId = UNDEFINED_NETWORK_ID;

            _updatePreviousZAssetsNetwork(
                _zAssetKey,
                currentZAssetInnerParams.networkId
            );
        }

        bytes32 _newZAssetInnerHash = _generateZAssetInnerHash(
            currentZAssetInnerParams
        );
        bytes32 newLeaf = _generateLeaf(_newZAssetInnerHash, weight);

        bytes32 zAssetsTreeRoot = update(
            _currentRoot,
            _currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings
        );

        _updateZAssetsRegistryAndStaticRoots(
            zAssetsTreeRoot,
            _newZAssetInnerHash,
            weight
        );
    }

    function _isZAssetExist(uint64 key) private view returns (bool) {
        return zAssetsInnerHash[key] != 0;
    }

    function _updateZAssetsInnerHash(uint64 key, bytes32 innerHash) private {
        zAssetsInnerHash[key] = innerHash;
    }

    function _updatePreviousZAssetsNetwork(
        uint64 zAssetKey,
        uint8 networkId
    ) private {
        previousZAssetsNetwork[zAssetKey] = networkId;
    }

    function _updateZAssetsRegistryAndStaticRoots(
        bytes32 zAssetsTreeRoot,
        bytes32 zAssetInnerHash,
        uint48 weight
    ) private {
        _currentRoot = zAssetsTreeRoot;
        _updateStaticRoot(zAssetsTreeRoot, ZASSET_STATIC_LEAF_INDEX);

        emit ZAssetRootUpdated(zAssetsTreeRoot, zAssetInnerHash, weight);
    }

    function _generateLeaf(
        bytes32 _zAssetInnerHash,
        uint48 _weight
    ) private pure returns (bytes32) {
        return
            PoseidonHashers.poseidonT3(
                [_zAssetInnerHash, bytes32(uint256(_weight))]
            );
    }

    function _generateZAssetInnerHash(
        ZAssetInnerParams memory zAssetInnerParams
    ) private pure returns (bytes32) {
        return
            PoseidonHashers.poseidonT6(
                [
                    bytes32(uint256(zAssetInnerParams.batchId)),
                    bytes32(
                        uint256(
                            zAssetInnerParams.token.encodeAddressWithType(
                                zAssetInnerParams.tokenType
                            )
                        )
                    ),
                    bytes32(uint256(zAssetInnerParams.startTokenId)),
                    bytes32(uint256(zAssetInnerParams.networkId)),
                    bytes32(
                        uint256(
                            zAssetInnerParams
                                .tokenIdsRangeSize
                                .encodeTokenIdRangeSizeWithScale(
                                    zAssetInnerParams.scaleFactor
                                )
                        )
                    )
                ]
            );
    }

    function _sanitizeZAssetParms(
        ZAssetInnerParams calldata zAssetInnerParams
    ) private pure {
        uint8 tokenType = zAssetInnerParams.tokenType;

        if (tokenType == ERC20_TOKEN_TYPE)
            _sanitizeErc20Params(zAssetInnerParams);
        else if (tokenType == NATIVE_TOKEN_TYPE)
            _sanitizeNativeParams(zAssetInnerParams);
        else if (tokenType == ERC721_TOKEN_TYPE)
            _sanitizeErc721Params(zAssetInnerParams);
        else if (tokenType == ERC1155_TOKEN_TYPE)
            _sanitizeErc721Params(zAssetInnerParams);
        else revert("ZAR: invalid token type");
    }

    function _sanitizeErc20Params(
        ZAssetInnerParams calldata _zAsset
    ) private pure {
        _checkNonZeroAddress(_zAsset.token);
        _checkZeroStartTokenID(_zAsset.startTokenId);
        _checkZeroTokenIdsRangeSize(_zAsset.tokenIdsRangeSize);
    }

    function _sanitizeNativeParams(
        ZAssetInnerParams calldata _zAsset
    ) private pure {
        _checkZeroAddress(_zAsset.token);
        _checkZeroStartTokenID(_zAsset.startTokenId);
        _checkZeroTokenIdsRangeSize(_zAsset.tokenIdsRangeSize);
    }

    function _sanitizeErc721Params(
        ZAssetInnerParams calldata _zAsset
    ) private pure {
        _checkNonZeroAddress(_zAsset.token);
        _checkZeroScaleFactor(_zAsset.scaleFactor);
    }

    function _checkNonZeroAddress(address token) private pure {
        require(token != address(0), "ZAR: zero token address");
    }

    function _checkZeroAddress(address token) private pure {
        require(token == address(0), "ZAR: non-zero token address");
    }

    function _checkZeroStartTokenID(uint32 startTokenId) private pure {
        require(startTokenId == 0, "ZAR: non-zero token id");
    }

    function _checkZeroTokenIdsRangeSize(
        uint32 tokenIdsRangeSize
    ) private pure {
        require(tokenIdsRangeSize == 0, "ZAR: non-zero offset");
    }

    function _checkZeroScaleFactor(uint8 scaleFactor) private pure {
        require(scaleFactor == 0, "ZAR: non-zero scale factor");
    }

    function _checkScaleFactor(uint8 scaleFactor) private pure {
        require(scaleFactor <= 32, "ZAR: too high scale factor");
    }

    function _checkErc20Weight(uint48 weight) private pure {
        require(weight <= type(uint32).max, "ZAR: too high erc20 weight");
    }

    function _checkSnarkFriendly(uint256 value) private pure {
        require(value < FIELD_SIZE, "ZAR: not snark friendly");
    }

    function _checkZAssetBatchId(uint64 id) private pure {
        require(id & type(uint32).max == 0, "ZAR: invalid batch id");
    }

    function _checkUpdatedWeight(
        WeightMetrics calldata weightMetrics
    ) private pure {
        require(weightMetrics.scUsdPrice >= 1e2, "ZAR: invalid usd price");

        require(
            ((10 ** weightMetrics.zAssetDecimal / weightMetrics.zAssetScale) *
                weightMetrics.updatedWeight) /
                weightMetrics.scUsdPrice ==
                TARGET_WEIGHTED_AMOUNT_PER_USD * 1e2,
            "ZAR: invalid weight"
        );
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
}
