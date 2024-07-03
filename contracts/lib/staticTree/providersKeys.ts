// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {PublicKey} from '@panther-core/crypto/lib/types/keypair';
import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber} from 'ethers';

import {pantherCoreZeroLeaf} from '../utilities';

const publicKey = [
    13277427435165878497778222415993513565335242147425444199013288855685581939618n,
    13622229784656158136036771217484571176836296686641868549125388198837476602820n,
] as PublicKey;

function packPublicKey(publicKey: PublicKey): bigint[] {
    return [BigInt(publicKey[0]), BigInt(publicKey[1])];
}

type RegisterKeyData = {
    keyringId: string;
    publicKey: PublicKey;
    expiryDate: BigNumberish;
};

export const leafs: RegisterKeyData[] = [
    {
        keyringId: '1',
        publicKey: publicKey,
        expiryDate: 1735689600n,
    },
    {
        keyringId: '2',
        publicKey: publicKey,
        expiryDate: 1735689600n + 1n,
    },
];

export class ProvidersKeys {
    leafs: RegisterKeyData[];
    commitments: string[] = [];
    root: string | null = null;
    providersKeyInsertionInputs: any[] = [];

    levels = 16;

    constructor(leafs: RegisterKeyData[]) {
        this.leafs = leafs;
    }

    _getZeroTree() {
        return new MerkleTree(
            poseidon,
            this.levels,
            BigInt(pantherCoreZeroLeaf),
        );
    }

    computeCommitments(): ProvidersKeys {
        this.commitments = this.leafs.map(leaf => {
            const {publicKey, expiryDate} = leaf;
            const packedKey = packPublicKey(publicKey);
            const inputs = [...packedKey, BigInt(expiryDate)];
            return poseidon(inputs).toString();
        });
        return this;
    }

    getInsertionInputs(): ProvidersKeys {
        const merkleTree = this._getZeroTree();
        this.computeCommitments();

        this.commitments.forEach((commitment: string, index: number) => {
            merkleTree.insert(BigInt(commitment));
            const proofSiblings = merkleTree
                .createProof(index)
                .siblingNodes.map(x => BigNumber.from(x).toHexString());

            const {keyringId, publicKey, expiryDate} = this.leafs[index];

            this.providersKeyInsertionInputs.push({
                keyringId,
                publicKey,
                expiryDate,
                proofSiblings,
            });
        });

        this.root = BigNumber.from(merkleTree.root).toHexString();

        return this;
    }
}
