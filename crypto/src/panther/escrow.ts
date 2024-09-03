// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {babyjub as bbj, poseidon} from 'circomlibjs';

import {generateRandomInBabyJubSubField} from '../base/field-operations';
import {
    CommonEscrowData,
    DAOEscrowData,
    DataEscrowData,
    EscrowEncryptedPoints,
    EscrowType,
} from '../types/escrow';
import {Keypair, Point, PublicKey} from '../types/keypair';

const LSB_252_BITS_MASK = (1n << 252n) - 1n;

/**
 * Encrypts data for escrow.
 * @param data - Data to be encrypted.
 * @param dataEscrowPublicKey - PublicKey for the escrow.
 * @param escrowType - Type of the escrow.
 * @returns Object containing ephemeral keypair and encrypted points.
 */
export function encryptDataForEscrow(
    data: CommonEscrowData,
    dataEscrowPublicKey: PublicKey,
    escrowType: EscrowType,
): {ephemeralKeypair: Keypair; escrowEncryptedPoints: EscrowEncryptedPoints} {
    const {ephemeralKeypair, encryptedPoints} = encryptDataIntoPointsOnBJJ(
        data,
        dataEscrowPublicKey,
        escrowType,
    );

    const escrowEncryptedPoints: EscrowEncryptedPoints = [
        encryptedPoints.map((p: Point) => p[0]),
        encryptedPoints.map((p: Point) => p[1]),
    ];

    return {ephemeralKeypair, escrowEncryptedPoints};
}

function shiftAndBitwiseOr(a: bigint, b: bigint, shift: number): bigint {
    return (a << BigInt(shift)) | b;
}

function encryptDataIntoPointsOnBJJ(
    data: CommonEscrowData,
    dataEscrowPublicKey: PublicKey,
    escrowType: EscrowType,
): {ephemeralKeypair: Keypair; encryptedPoints: Point[]} {
    const scalars = convertEscrowDataToScalars(data, escrowType);
    const points: Point[] = scalars.map(
        scalar => bbj.mulPointEscalar(bbj.Base8, scalar) as Point,
    );

    if (escrowType === EscrowType.DAO || escrowType === EscrowType.Zone) {
        points.push((data as DAOEscrowData).ephemeralPubKey);
    } else if (escrowType === EscrowType.Data) {
        points.push(...(data as DataEscrowData).utxoOutSpendingPublicKeys);
    }

    return encryptPointsElGamal(points, dataEscrowPublicKey, escrowType);
}

function convertEscrowDataToScalars(
    data: CommonEscrowData,
    escrowType: EscrowType,
): bigint[] {
    switch (escrowType) {
        case EscrowType.Zone:
        case EscrowType.DAO:
            return [];
        case EscrowType.Data:
            return convertDataEscrowToScalars(data as DataEscrowData);
        default:
            throw new Error('Invalid escrow type');
    }
}

/**
 * Converts Data escrow to scalars.
 * @param data - The Data escrow data.
 * @returns An array of bigints representing the scalar values.
 */
export function convertDataEscrowToScalars(data: DataEscrowData): bigint[] {
    const {
        zAccountID,
        zAccountZoneId,
        zAccountNonce,
        zAssetID,
        utxoInAmounts,
        utxoOutAmounts,
        utxoInOriginZoneIds,
        utxoOutTargetZoneIds,
        utxoInMerkleTreeSelector,
        utxoInPathIndices,
    } = data;

    const treeSelectors = convertToLittleEndianBigInts(
        utxoInMerkleTreeSelector,
    );
    const leafIndices = convertToLittleEndianBigInts(utxoInPathIndices);

    return [
        zAssetID,
        combineZAccountInfo(treeSelectors, zAccountID, zAccountZoneId),
        zAccountNonce,
        ...utxoInAmounts,
        ...utxoOutAmounts,
        ...combineUtxoInfo(
            leafIndices,
            utxoInOriginZoneIds,
            utxoOutTargetZoneIds,
        ),
    ];
}

function convertToLittleEndianBigInts(arrays: bigint[][]): bigint[] {
    return arrays.map(arr => BigInt('0b' + arr.slice().reverse().join('')));
}

function combineZAccountInfo(
    treeSelectors: bigint[],
    zAccountID: bigint,
    zAccountZoneId: bigint,
): bigint {
    return shiftAndBitwiseOr(
        treeSelectors[1],
        shiftAndBitwiseOr(
            treeSelectors[0],
            shiftAndBitwiseOr(zAccountID, zAccountZoneId, 16),
            40,
        ),
        42,
    );
}

function combineUtxoInfo(
    leafIndices: bigint[],
    utxoInOriginZoneIds: bigint[],
    utxoOutTargetZoneIds: bigint[],
): bigint[] {
    return leafIndices.map((leafIndex, i) =>
        shiftAndBitwiseOr(
            leafIndex,
            shiftAndBitwiseOr(
                utxoInOriginZoneIds[i],
                utxoOutTargetZoneIds[i],
                16,
            ),
            32,
        ),
    );
}

export function maskPoint(originalPoint: Point, maskingPoint: Point): Point {
    return bbj.addPoint(originalPoint, maskingPoint) as Point;
}

export function unmaskPoint(encryptedPoint: Point, maskingPoint: Point): Point {
    const negatedMaskingPoint = [bbj.p - maskingPoint[0], maskingPoint[1]];
    return bbj.addPoint(encryptedPoint, negatedMaskingPoint) as Point;
}

function encryptPointsElGamal(
    originalPoints: Point[],
    publicKey: PublicKey,
    escrowType: EscrowType,
): {encryptedPoints: Point[]; ephemeralKeypair: Keypair} {
    const ephemeralRandom = generateRandomInBabyJubSubField();
    const ephemeralKeys = ephemeralPublicKeyBuilder(
        ephemeralRandom,
        publicKey,
        originalPoints.length,
    );

    const encryptedPoints = originalPoints.map((p0, idx) => {
        const p1 = maskPoint(p0, ephemeralKeys.sharedPubKeys[idx] as Point);
        return escrowType === EscrowType.Data
            ? maskPoint(p1, ephemeralKeys.hidingPoint)
            : p1;
    });

    return {
        encryptedPoints,
        ephemeralKeypair: {
            privateKey: ephemeralRandom,
            publicKey: ephemeralKeys.ephemeralPubKeys[0],
        },
    };
}

export function ephemeralPublicKeyBuilder(
    ephemeralRandom: bigint,
    publicKey: PublicKey,
    length: number,
): {
    ephemeralPubKeys: PublicKey[];
    sharedPubKeys: PublicKey[];
    hidingPoint: Point;
} {
    const ephemeralPubKeys: PublicKey[] = [];
    const sharedPubKeys: PublicKey[] = [];

    for (let i = 0; i < length; i++) {
        const {ephemeralPubKey, sharedPubKey} = generateKeyPair(
            ephemeralRandom,
            publicKey,
        );
        ephemeralPubKeys.push(ephemeralPubKey);
        sharedPubKeys.push(sharedPubKey);
        ephemeralRandom = generateNewEphemeralRandom(sharedPubKey);
    }

    const hidingPoint = bbj.mulPointEscalar(
        publicKey,
        generateNewEphemeralRandom([poseidon(sharedPubKeys[0])]),
    ) as PublicKey;

    return {ephemeralPubKeys, sharedPubKeys, hidingPoint};
}

function generateKeyPair(
    ephemeralRandom: bigint,
    publicKey: PublicKey,
): {ephemeralPubKey: PublicKey; sharedPubKey: PublicKey} {
    const ephemeralPubKey = bbj.mulPointEscalar(
        bbj.Base8,
        ephemeralRandom,
    ) as PublicKey;
    const sharedPubKey = bbj.mulPointEscalar(
        publicKey,
        ephemeralRandom,
    ) as PublicKey;
    return {ephemeralPubKey, sharedPubKey};
}

function generateNewEphemeralRandom(seed: bigint[]): bigint {
    return poseidon(seed) & LSB_252_BITS_MASK;
}
