// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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
            9487832625653172027749782479736182284968410276712116765581383594391603612850n,
            20341243520484112812812126668555427080517815150392255522033438580038266039458n,
        ],
        expiryDate: 1767225600n,
    },
    {
        keyringId: FIRST_KEYRING_ID,
        publicKey: [
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
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
