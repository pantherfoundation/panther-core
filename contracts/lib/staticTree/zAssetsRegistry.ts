// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber} from 'ethers';

import {encodeTokenTypeAndAddress, decodeTokenTypeAndAddress} from '../token';
import {pantherCoreZeroLeaf} from '../utilities';

const amoyNetworkId = 1n;
const polygonNetworkId = 2n;

interface TokenDetails {
    [key: string]: {[key: string]: Token}; // Adjust value type as necessary
}

type TokenType = 'ERC20' | 'ERC721' | 'ERC1155' | 'Native';

type Token = {
    address: string;
    weight: BigNumberish;
    scale: BigNumberish;
    decimals: BigNumberish;
    type: TokenType;
    networkId: BigNumberish;
};

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
    networkId: BigNumberish;
    // Irrelevant for ERC-20 and the native token
    tokenIdsRangeSize: bigint;
    // Weight of the token
    weight: BigNumberish;
    // scale factor
    scale: BigNumberish;
    decimals: BigNumberish;
};

export const tokenDetails: TokenDetails = {
    amoy: {
        ZKP_TOKEN: {
            address: '0x9C56E89D8Aa0d4A1fB769DfbEa80D6C29e5A2893',
            weight: 110n,
            scale: BigInt(1e14),
            decimals: 18n,
            type: 'ERC20',
            networkId: amoyNetworkId,
        },
        NATIVE_TOKEN: {
            address: ethers.constants.AddressZero,
            weight: 5000n,
            scale: BigInt(1e14),
            decimals: 18n,
            type: 'Native',
            networkId: amoyNetworkId,
        },
        LINK_TOKEN: {
            address: '0xA82B5942DD61949Fd8A2993dCb5Ae6736F8F9E60',
            weight: 1400n,
            scale: BigInt(1e12),
            decimals: 18n,
            type: 'ERC20',
            networkId: amoyNetworkId,
        },
    },
    polygon: {
        ZKP_TOKEN: {
            address: '0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC',
            weight: 110n,
            scale: BigInt(1e14),
            decimals: 18n,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        NATIVE_TOKEN: {
            address: ethers.constants.AddressZero,
            weight: 4500n,
            scale: BigInt(1e14),
            decimals: 18n,
            type: 'Native',
            networkId: polygonNetworkId,
        },
        LINK_TOKEN: {
            address: '0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39',
            weight: 1400n,
            scale: BigInt(1e12),
            decimals: 18n,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        UNI: {
            address: '0xb33EaAd8d922B1083446DC23f610c2567fB5180f',
            weight: 920n,
            scale: BigInt(1e12),
            decimals: 18n,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        AAVE: {
            address: '0xD6DF932A45C0f255f85145f286eA0b292B21C90B',
            weight: 1700n,
            scale: BigInt(1e11),
            decimals: 18n,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        GRT: {
            address: '0x5fe2B58c013d7601147DcdD68C143A77499f5531',
            weight: 2200n,
            scale: BigInt(1e14),
            decimals: 18n,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
        QUICK: {
            address: '0xB5C064F955D8e7F38fE0460C556a72987494eE17',
            weight: 417n,
            scale: BigInt(1e14),
            decimals: 6n,
            type: 'ERC20',
            networkId: polygonNetworkId,
        },
    },
};

function zAssetBatchId(batchIndex: number): bigint {
    // note: 32 LS bits are unused and should be zero that's why we are
    // doing left shift by 32 bits
    return BigInt(batchIndex) << 32n;
}

function createLeafs(network: string): ZAsset[] {
    const res = Object.entries(tokenDetails[network]).map(
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
                zAssetId: 0n,
                token: address,
                startTokenId: 0,
                tokenAddrAndType,
                networkId,
                tokenIdsRangeSize: 0n,
                weight,
                scale,
                decimals,
            };
        },
    );

    return res;
}

export const leafs = (network: string): ZAsset[] => createLeafs(network);

export class ZAssetsRegistry {
    leafs: ZAsset[];
    commitments: string[] = [];
    root: string | null = null;
    zAssetRegistryParams: any[] = [];
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
                leaf.networkId,
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
            const weight = this.leafs[index].weight;

            merkleTree.insert(commitment);
            const proofSiblings = merkleTree
                .createProof(index)
                .siblingNodes.map(x => BigNumber.from(x).toHexString());

            this.zAssetRegistryParams.push({
                token: decodeTokenTypeAndAddress(this.leafs[index].token)
                    .address,
                batchId: this.leafs[index].zAssetbatchId,
                startTokenId: this.leafs[index].startTokenId,
                tokenIdsRangeSize: Number(this.leafs[index].tokenIdsRangeSize),
                scale: this.leafs[index].scale,
                networkId: Number(this.leafs[index].networkId),
                tokenType: decodeTokenTypeAndAddress(this.leafs[index].token)
                    .type,
            });

            this.zAssetRegistryInsertionInputs.push({
                zAssetRegistryParams: this.zAssetRegistryParams,
                currentRoot,
                currentLeaf,
                newLeaf,
                leafIndex,
                weight,
                proofSiblings,
            });
        });

        this.root = BigNumber.from(merkleTree.root).toHexString();

        return this;
    }
}
