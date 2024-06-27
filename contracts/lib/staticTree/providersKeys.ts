// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {PublicKey} from '@panther-core/crypto/lib/types/keypair';
import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber} from 'ethers';

type RegisterKeyData = {
    keyringId: string;
    publicKey: PublicKey;
    expiryDate: BigNumberish;
    proofSiblings: string[];
};

export const ProvidersKeys = (): RegisterKeyData[] => {
    const publicKey = [
        13277427435165878497778222415993513565335242147425444199013288855685581939618n,
        13622229784656158136036771217484571176836296686641868549125388198837476602820n,
    ] as PublicKey;

    const expiryDate = 1735689600n; // 2025-01-01T00:00:00Z

    const zeroValue =
        '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d';
    const kycKytMerkleTree = new MerkleTree(poseidon, 16, zeroValue);

    const kycKytMerkleTreeLeaf1 = poseidon([
        publicKey[0], // x
        publicKey[1], // y
        expiryDate,
    ]);

    const kycKytMerkleTreeLeaf2 = poseidon([
        publicKey[0], // x
        publicKey[1], // y
        expiryDate + 1n, // Slightly different expiry to ensure different proof
    ]);

    kycKytMerkleTree.insert(kycKytMerkleTreeLeaf1);
    const proof1 = kycKytMerkleTree.createProof(0);

    kycKytMerkleTree.insert(kycKytMerkleTreeLeaf2);
    const proof2 = kycKytMerkleTree.createProof(1);

    return [
        {
            keyringId: '1',
            publicKey,
            expiryDate,
            proofSiblings: proof1.siblingNodes.map(x =>
                BigNumber.from(x).toHexString(),
            ),
        },
        {
            keyringId: '2',
            publicKey,
            expiryDate: expiryDate + 1n,
            proofSiblings: proof2.siblingNodes.map(x =>
                BigNumber.from(x).toHexString(),
            ),
        },
    ];
};
