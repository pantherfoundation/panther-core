// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber} from 'ethers';

import {pantherCoreZeroLeaf} from '../utilities';

type ZAsset = {
    // zAssetId, but it's not the leaf index
    zAsset: BigNumberish;
    // address of the token contract on this network
    token: BigNumberish;
    // ID for NFTs, irrelevant for ERC-20 and the native token
    tokenId: BigNumberish;
    // ID of the network where zAsset lives
    network: BigNumberish;
    // Irrelevant for ERC-20 and the native token
    offset: BigNumberish;
    // Weight of the token
    weight: BigNumberish;
    // scale factor
    scale: BigNumberish;
};

export const leafs: ZAsset[] = [
    // zZKP
    {
        zAsset: 0,
        // zkp token on sepolia
        token: BigInt('0x9FBF5b80F2CfcB851dfE92272ae133eaD6786483'),
        // ID for NFTs, irrelevant for ERC-20 and the native token
        tokenId: 0,
        // sepolia network id
        network: 2,
        offset: 0,
        // 1 ZKP = 1e6 scaled units * 20 = 2e7 weighted units
        weight: 20,
        // 1 ZKP = 1e18 unscaled units / 1e12 = 1e6 scaled units
        scale: 1e12,
    },
    // zEth on sepolia
    {
        // IDs for the native tokens of different networks MUST be different
        // i.e. 1 for zEth, 2 for zMatic, etc.
        // TODO: starting zEth from 1
        zAsset: 2,
        // MUST be 0 for the native token on all networks
        token: 0,
        // ID for NFTs, irrelevant for ERC-20 and the native token
        tokenId: 0,
        // sepolia network id
        network: 2,
        offset: 0,
        //1 Eth = 1e6 scaled units * 700 = 7e8 weighted units
        weight: 700,
        // 1 Eth = 1e18 unscaled units / 1e12 = 1e6 scaled units
        scale: 1e12,
    },
];

export class ZAssetsRegistry {
    leafs: ZAsset[];
    commitments: string[] = [];
    root: string | null = null;
    zAssetRegistryInsertionInputs: any[] = [];

    levels = 16;

    constructor(leafs: ZAsset[]) {
        this.leafs = leafs;
    }

    _getZeroTree() {
        return new MerkleTree(
            poseidon,
            this.levels,
            BigInt(pantherCoreZeroLeaf),
        );
    }

    computeCommitments(): ZAssetsRegistry {
        this.commitments = this.leafs.map(leaf =>
            poseidon(Object.values(leaf)),
        );
        return this;
    }

    getInsertionInputs(): ZAssetsRegistry {
        const merkleTree = this._getZeroTree();
        this.computeCommitments();

        this.commitments.forEach((commitment: string, index: number) => {
            const currentRoot = BigNumber.from(merkleTree.root).toHexString();
            const currentLeaf =
                BigNumber.from(pantherCoreZeroLeaf).toHexString();
            const newLeaf = BigNumber.from(commitment).toHexString();
            const leafIndex = BigNumber.from(index).toHexString();

            merkleTree.insert(commitment);
            const proofSiblings = merkleTree
                .createProof(index)
                .siblingNodes.map(x => BigNumber.from(x).toHexString());

            this.zAssetRegistryInsertionInputs.push({
                currentRoot,
                currentLeaf,
                newLeaf,
                leafIndex,
                proofSiblings,
            });
        });

        this.root = BigNumber.from(merkleTree.root).toHexString();

        return this;
    }
}
