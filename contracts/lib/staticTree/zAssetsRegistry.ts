// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber} from 'ethers';

import {encodeTokenTypeAndAddress} from '../../test/protocol/helpers/pantherPoolV1Inputs';
import {pantherCoreZeroLeaf} from '../utilities';

import {tokenDetails, NetworkType} from './staticTreeConfig';

function zAssetBatchId(batchIndex: number): bigint {
    // note: 32 LS bits are unused and should be zero that's why we are
    // doing left shift by 32 bits
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

function createLeafs(networkType: NetworkType): ZAsset[] {
    return Object.entries(tokenDetails[networkType]).map(
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        ([key, value], index) => {
            const {address, weight, scale, decimals, type, networkId} = value;
            const zAssetbatchId = zAssetBatchId(index);
            const tokenAddrAndType = encodeTokenTypeAndAddress(
                type === 'Native' ? 0xff : 0,
                address,
            );

            return {
                zAssetbatchId,
                zAssetId: zAssetbatchId,
                token: type === 'Native' ? address : BigInt(address),
                startTokenId: 0,
                tokenAddrAndType,
                network: networkId,
                tokenIdsRangeSize: 0n,
                weight,
                scale,
                decimals,
            };
        },
    );
}

export const leafs = (networkType: NetworkType): ZAsset[] =>
    createLeafs(networkType);

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
