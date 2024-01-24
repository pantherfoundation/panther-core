// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "./pantherForest/interfaces/ITreeRootUpdater.sol";
import "./pantherForest/interfaces/ITreeRootGetter.sol";

import "./pantherForest/merkleTrees/BinaryUpdatableTree.sol";
import "./crypto/PoseidonHashers.sol";
import "../common/ImmutableOwnable.sol";

import { ZNETWORK_STATIC_LEAF_INDEX } from "./pantherForest/Constants.sol";
import { SIX_LEVEL_EMPTY_TREE_ROOT } from "./pantherForest/zeroTrees/Constants.sol";

/**
 * @title ZNetworksRegistry
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of assets (tokens) supported by the Panther
 * Protocol Multi-Asset Shielded Pool (aka "MASP")
 */

contract ZNetworksRegistry is
    ImmutableOwnable,
    BinaryUpdatableTree,
    ITreeRootGetter
{
    ITreeRootUpdater public immutable PANTHER_STATIC_TREE;

    // The current root of merkle tree.
    // If it's undefined, the `zeroRoot()` shall be called.
    bytes32 private _currentRoot;

    event ZNetworkTreeUpdated(bytes32 newRoot);

    constructor(
        address _owner,
        address pantherStaticTree
    ) ImmutableOwnable(_owner) {
        require(pantherStaticTree != address(0), "Init");

        PANTHER_STATIC_TREE = ITreeRootUpdater(pantherStaticTree);
    }

    function getRoot() external view returns (bytes32) {
        return _currentRoot == bytes32(0) ? zeroRoot() : _currentRoot;
    }

    function addNetwork(
        bytes32 curRoot,
        bytes32 curLeaf,
        bytes32 newLeaf,
        uint256 leafIndex,
        bytes32[] calldata proofSiblings
    ) external onlyOwner {
        bytes32 zNetworkTreeRoot = update(
            curRoot,
            curLeaf,
            newLeaf,
            leafIndex,
            proofSiblings
        );

        // Trusted contract - no reentrancy guard needed
        PANTHER_STATIC_TREE.updateRoot(
            zNetworkTreeRoot,
            ZNETWORK_STATIC_LEAF_INDEX
        );

        emit ZNetworkTreeUpdated(zNetworkTreeRoot);
    }

    //@dev returns the root of tree with depth 16 where each leaf is ZERO_VALUE
    function zeroRoot() internal pure override returns (bytes32) {
        return SIX_LEVEL_EMPTY_TREE_ROOT;
    }

    function hash(
        bytes32[2] memory input
    ) internal pure override returns (bytes32) {
        return PoseidonHashers.poseidonT3(input);
    }

    /**
    In the Public Stage Contracts:
        Consists of two leafs: for Goerli and Munbai
        root: 0x0af52519043cafcc6b83b72bc01e33e1c2d24a9cfea7f2e1d984f3895d3bfba4

    Leaf for Goerli
    leaf index: 0
    commitment: 0x27ccd63f1c836714a032ec22dbcadfcc425e985211e513c573b1cfad5b926205,
    = poseidon([
        // param: active
        1,
        // param: chainId
        5,
        // param: networkId
        1,
        // param: networkIDsBitMap
        // One-bit flags enabling creating/spending on this network UTXOs spendable/created on
        // other networks; LS bit for the network with ID 1, followed by the bit for the ID 2, ...)
        // (networks with IDs 1 and 2 are enabled)
        3,
        // param: forTxReward
        10,
        // param: forUtxoReward
        1828,
        // param: forDepositReward
        57646075,
        // param: daoDataEscrowPubKey[0]
        6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        // param: daoDataEscrowPubKey[1]
        12531080428555376703723008094946927789381711849570844145043392510154357220479n
    ])

    siblings: [
    '0x0b2d29a71a1acffec0bae071a7e738e6a7c8efec628974e6691b5843b8a98248',
    '0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4',
    '0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8',
    '0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c',
    '0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800',
    '0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f'
    ]

    Leaf for Mumbai
    leaf index: 1
    commitment: 0x0b2d29a71a1acffec0bae071a7e738e6a7c8efec628974e6691b5843b8a98248,
    = poseidon([
        // param: active
        1,
        // param: chainId
        80001,
        // param: networkId
        2,
        // param: networkIDsBitMap
        // One-bit flags enabling creating/spending on this network UTXOs spendable/created on
        // other networks; LS bit for the network with ID 1, followed by the bit for the ID 2, ...)
        // (networks with IDs 1 and 2 are enabled)
        3,
        // param: forTxReward
        10,
        // param: forUtxoReward
        1828,
        // param: forDepositReward
        57646075,
        // param: daoDataEscrowPubKey[0]
        6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        // param: daoDataEscrowPubKey[1]
        12531080428555376703723008094946927789381711849570844145043392510154357220479n
    ])

    siblings: [
    '0x27ccd63f1c836714a032ec22dbcadfcc425e985211e513c573b1cfad5b926205',
    '0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4',
    '0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8',
    '0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c',
    '0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800',
    '0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f'
    ]
*/
}
