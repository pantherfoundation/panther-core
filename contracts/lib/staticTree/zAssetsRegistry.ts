// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber, ethers} from 'ethers';

import {encodeTokenTypeAndAddress} from '../../test/protocol/helpers/pantherPoolV1Inputs';
import {pantherCoreZeroLeaf} from '../utilities';

const zkpToken = '0x9C56E89D8Aa0d4A1fB769DfbEa80D6C29e5A2893'; //Internal zkp token address
const linkToken = '0xA82B5942DD61949Fd8A2993dCb5Ae6736F8F9E60';
const amoyNetworkId = 2;

function zAssetBatchId(batchIndex: number): bigint {
    // note: 32 LS bits are unused and should be zero that's why we are
    // doing left shift by 32 bits
    console.log('batch id', BigInt(batchIndex) << 32n);
    return BigInt(batchIndex) << 32n;
}

type ZAsset = {
    // zAssetbatchId, but it's not the leaf index
    zAssetbatchId: BigNumberish;
    // zAssetId MUST be 0 for ZKP on all networks
    zAssetId: BigNumberish;
    // address of the token contract on this network
    token: BigNumberish;
    // ID for NFTs, irrelevant for ERC-20 and the native token
    startTokenId: BigNumberish;
    // token address followed by the token type(ERC-20/721/1155)
    tokenAddrAndType: BigNumberish;
    // ID of the network where zAsset lives
    network: BigNumberish;
    // Irrelevant for ERC-20 and the native token
    tokenIdsRangeSize: bigint;
    // Weight of the token
    weight: BigNumberish;
    // scale factor
    scale: bigint;
    decimals: number;
};

export const leafs: ZAsset[] = [
    // zZKP
    {
        zAssetbatchId: zAssetBatchId(0),
        zAssetId: zAssetBatchId(0),
        // zkp token on amoy
        token: BigInt(zkpToken),
        startTokenId: 0,
        tokenAddrAndType: encodeTokenTypeAndAddress(0, zkpToken),
        network: amoyNetworkId,
        tokenIdsRangeSize: 0n,
        weight: 100,
        scale: BigInt(1e14),
        decimals: 18,
    },
    // zMatic on amoy
    {
        zAssetbatchId: zAssetBatchId(1),
        zAssetId: zAssetBatchId(1),
        // MUST be 0 for the native token on all networks
        token: ethers.constants.AddressZero,
        startTokenId: 0,
        tokenAddrAndType: encodeTokenTypeAndAddress(
            0xff,
            ethers.constants.AddressZero,
        ),
        network: amoyNetworkId,
        tokenIdsRangeSize: 0n,
        weight: 5000,
        scale: BigInt(1e14),
        decimals: 18,
    },
    {
        zAssetbatchId: zAssetBatchId(2),
        zAssetId: zAssetBatchId(2),
        // Link token on amoy
        token: BigInt(linkToken),
        startTokenId: 0,
        tokenAddrAndType: encodeTokenTypeAndAddress(0, linkToken),
        network: amoyNetworkId,
        tokenIdsRangeSize: 0n,
        weight: 1400,
        scale: BigInt(1e12),
        decimals: 18,
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
        this.commitments = this.leafs.map(leaf => {
            const hash = poseidon([
                leaf.zAssetbatchId,
                leaf.tokenAddrAndType,
                leaf.startTokenId,
                leaf.network,
                (leaf.tokenIdsRangeSize << 64n) + BigInt(leaf.scale.toString()),
            ]);
            return poseidon([hash, BigInt(leaf.weight.toString())]);
        });
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
