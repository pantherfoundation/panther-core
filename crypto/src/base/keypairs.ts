// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

// The code is inspired by applied ZKP
/*
Some of the functions are modified version or inspired by this code:
https://github.com/appliedzkp/maci/blob/master/crypto/ts/index.ts
*/

// @ts-ignore
import {babyjub} from 'circomlibjs';

import {Keypair, PrivateKey, PublicKey} from '../types/keypair';
import {
    assertInSnarkField,
    assertInBabyJubJubSubOrder,
    assert,
} from '../utils/assertions';

import {
    moduloBabyJubSubFieldPrime,
    generateRandomInBabyJubSubField,
} from './field-operations';

export const PACKED_PUB_KEY_SIZE = 32;
export const PRIV_KEY_SIZE = 32;

export const isChildPubKeyValid = (
    childPubKey: PublicKey,
    rootKeypair: Keypair,
    randomSecret: bigint,
): boolean => {
    assertInSnarkField(childPubKey[0], 'Child public key X');
    assertInSnarkField(childPubKey[1], 'Child public key Y');
    assertInSnarkField(rootKeypair.publicKey[0], 'Root public key X');
    assertInSnarkField(rootKeypair.publicKey[1], 'Root public key Y');
    const rs = deriveChildPrivKeyFromRootPrivKey(
        rootKeypair.privateKey,
        randomSecret,
    );
    const rs_B = derivePubKeyFromPrivKey(rs);
    const s_rB = deriveChildPubKeyFromRootPubKey(
        rootKeypair.publicKey,
        randomSecret,
    );
    const isValid =
        childPubKey[0] === rs_B[0] &&
        childPubKey[1] === rs_B[1] &&
        s_rB[0] === childPubKey[0] &&
        s_rB[1] === childPubKey[1];

    console.debug(`generated public key is${isValid ? '' : ' NOT'} valid`);
    return isValid;
};

export const deriveKeypairFromPrivKey = (privateKey: bigint): Keypair => {
    assertInBabyJubJubSubOrder(privateKey, 'privateKey');
    const publicKey = derivePubKeyFromPrivKey(privateKey);
    return {privateKey, publicKey};
};

export const deriveKeypairFromSeed = (seed: bigint): Keypair => {
    assert(seed != BigInt(0), 'Zero seed is not allowed');
    const privateKey = moduloBabyJubSubFieldPrime(seed);
    return deriveKeypairFromPrivKey(privateKey);
};

export const derivePubKeyFromPrivKey = (privateKey: PrivateKey): PublicKey => {
    assertInBabyJubJubSubOrder(privateKey, 'privateKey');
    return babyjub.mulPointEscalar(babyjub.Base8, privateKey) as PublicKey;
};

export const deriveChildPubKeyFromRootPubKey = (
    rootPubKey: PublicKey,
    random: bigint,
): PublicKey => {
    // MUST (not asserted here): rootPubKey to be generated from the babyjub.Base8
    assertInBabyJubJubSubOrder(random, 'random');
    assertInSnarkField(rootPubKey[0], 'Root public key X');
    assertInSnarkField(rootPubKey[1], 'Root public key Y');
    return babyjub.mulPointEscalar(rootPubKey, random) as PublicKey;
};

export const deriveChildPrivKeyFromRootPrivKey = (
    rootPrivKey: PrivateKey,
    random: bigint,
): PrivateKey => {
    assertInBabyJubJubSubOrder(rootPrivKey, 'Root private key');
    assertInBabyJubJubSubOrder(random, 'Random');
    return moduloBabyJubSubFieldPrime(rootPrivKey * random);
};

// packPublicKey packs the pub key and switches representation from
// little-endian to big-endian representation
export function packPublicKey(pubKey: PublicKey): Uint8Array {
    return babyjub.packPoint(pubKey).reverse();
}

// unpackPublicKey switches representation from big-endian to little-endian and
// unpacks the pub key
export function unpackPublicKey(packedPubKey: Uint8Array): PublicKey {
    return babyjub.unpackPoint([...packedPubKey].reverse()) as PublicKey;
}

export const generateRandomKeypair = () =>
    deriveKeypairFromPrivKey(generateRandomInBabyJubSubField());
