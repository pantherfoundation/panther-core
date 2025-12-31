// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {PublicKey} from '@panther-core/crypto/lib/types/keypair';
import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber} from 'ethers';

import {pantherCoreZeroLeaf} from '../utilities';

type RegisterKeyData = {
    keyringId: string;
    publicKey: PublicKey;
    expiryDate: BigNumberish;
};

const FIRST_KEYRING_ID = '1';

// Purify keys on test network.
// Don't use them on mainn or local networks
export const testnetLeafs: RegisterKeyData[] = [
    {
        keyringId: FIRST_KEYRING_ID,
        publicKey: [
            4905057968932000075776938242037250492381415265957616924603694372626611554719n,
            3859304740083170982790430217687216696322541315220140739968044011765517239052n,
        ],
        expiryDate: 1767225600n,
    },
    {
        keyringId: FIRST_KEYRING_ID,
        publicKey: [
            18413814951237948943276034097619662989571955823230653993719732444565232428850n,
            5997788321689024580770956870746360957990400045073833197489173157038887468581n,
        ],
        expiryDate: 1767225600n,
    },
];

export const polygonLeaf: RegisterKeyData[] = [
    {
        keyringId: FIRST_KEYRING_ID,
        publicKey: [
            4905057968932000075776938242037250492381415265957616924603694372626611554719n,
            3859304740083170982790430217687216696322541315220140739968044011765517239052n,
        ],
        expiryDate: 1767225600n,
    },
    {
        keyringId: FIRST_KEYRING_ID,
        publicKey: [
            18413814951237948943276034097619662989571955823230653993719732444565232428850n,
            5997788321689024580770956870746360957990400045073833197489173157038887468581n,
        ],
        expiryDate: 1767225600n,
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
            const inputs = [...publicKey, expiryDate];

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
