// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {poseidon} from 'circomlibjs';
import {Signer} from 'ethers';

import {
    moduloBabyJubSubFieldPrime,
    moduloSnarkFieldPrime,
} from '../base/field-operations';
import {
    deriveKeypairFromPrivKey,
    deriveChildPrivKeyFromRootPrivKey,
    deriveKeypairFromSeed,
    deriveChildPubKeyFromRootPubKey,
    isChildPubKeyValid,
} from '../base/keypairs';
import {Keypair, WalletKeypairs, PrivateKey, PublicKey} from '../types/keypair';
import {assertInBabyJubJubSubOrder, assert} from '../utils/assertions';

// generateSpendingChildKeypair generates child spending keypair (s', S')
// using root spending private key and random scalar r as input.
export function generateSpendingChildKeypair(
    rootSpendingPrivKey: PrivateKey,
    r: bigint,
): Keypair {
    const spendingChildPrivKey = deriveChildPrivKeyFromRootPrivKey(
        rootSpendingPrivKey,
        r,
    );
    return deriveKeypairFromSeed(spendingChildPrivKey);
}

export function generateChildSpendingPublicKey(
    rootSpendingPubKey: PublicKey,
    r: bigint,
): PublicKey {
    return deriveChildPubKeyFromRootPubKey(rootSpendingPubKey, r);
}

export const extractSecretsPair = (
    signature: string,
): [r: bigint, s: bigint] => {
    if (!signature) throw new Error('Signature must be provided');

    assert(
        signature.length === 132,
        `Tried to create keypair from signature of length '${signature.length}'`,
    );
    assert(
        signature.slice(0, 2) === '0x',
        `Tried to create keypair from signature without 0x prefix`,
    );
    // We will never verify this signature; we're only using it as a
    // deterministic source of entropy which can be used in a ZK proof.
    // So we can discard the LSB v which has the least entropy.
    const r = signature.slice(2, 66);
    const s = signature.slice(66, 130);
    return [
        moduloSnarkFieldPrime(BigInt('0x' + r)),
        moduloSnarkFieldPrime(BigInt('0x' + s)),
    ];
};

export function derivePrivKeyFromSignature(signature: string): bigint {
    const pair = extractSecretsPair(signature);
    if (!pair) {
        throw new Error('Failed to extract secrets pair from signature');
    }
    const privKey = moduloBabyJubSubFieldPrime(poseidon(pair));
    assertInBabyJubJubSubOrder(privKey, 'privateKey');
    return privKey;
}

export const KEY_INDEX_MAP = {
    ROOT_SPENDING: 1,
    ROOT_READING: 2,
    STORAGE_ENCRYPTION: 3,
    NULLIFIER_ROOT: 4,
} as const;

export type KeyIndex = (typeof KEY_INDEX_MAP)[keyof typeof KEY_INDEX_MAP];
export const VALID_INDICES = new Set<number>(Object.values(KEY_INDEX_MAP));

export function deriveKeypair(seed: bigint, index: number): Keypair {
    assert(seed != BigInt(0), 'Zero seed is not allowed');
    assert(VALID_INDICES.has(index), `Index ${index} out of derivation bounds`);

    const privateKey = moduloBabyJubSubFieldPrime(
        poseidon([seed, BigInt(index)]),
    );
    return deriveKeypairFromPrivKey(privateKey);
}

export async function deriveRootKeypairs(
    signer: Signer,
): Promise<WalletKeypairs> {
    const derivationMessage = `Greetings from Panther Protocol!

Sign this message in order to obtain the keys to your Panther wallet.

This signature will not cost you any fees.

Keypair version: 1`;

    const signature = await signer.signMessage(derivationMessage);
    const hashedSignature: bigint = poseidon([signature]);
    const derive = (index: number) => deriveKeypair(hashedSignature, index);

    return {
        rootSpendingKeypair: derive(1),
        rootReadingKeypair: derive(2),
        storageEncryptionKeypair: derive(3),
        nullifierRootKeypair: derive(4),
    };
}

export function deriveZoneNullifierKeypair(
    rootNullifierKeypair: Keypair,
    zoneId: bigint,
): Keypair {
    const zoneScalar = moduloBabyJubSubFieldPrime(poseidon([zoneId]));

    const zonePrivKey = deriveChildPrivKeyFromRootPrivKey(
        rootNullifierKeypair.privateKey,
        zoneScalar,
    );

    const zonePubKey = deriveChildPubKeyFromRootPubKey(
        rootNullifierKeypair.publicKey,
        zoneScalar,
    );

    return {
        privateKey: zonePrivKey,
        publicKey: zonePubKey,
    };
}

export function deriveSpendingChildKeypair(
    rootSpendingKeypair: Keypair,
    randomSecret: bigint,
): [Keypair, boolean] {
    const childSpendingPrivateKey = deriveChildPrivKeyFromRootPrivKey(
        rootSpendingKeypair.privateKey,
        randomSecret,
    );

    const spendingChildPubKey = deriveChildPubKeyFromRootPubKey(
        rootSpendingKeypair.publicKey,
        randomSecret,
    );

    const isValid = isChildPubKeyValid(
        spendingChildPubKey,
        rootSpendingKeypair,
        randomSecret,
    );

    return [
        {privateKey: childSpendingPrivateKey, publicKey: spendingChildPubKey},
        isValid,
    ];
}
