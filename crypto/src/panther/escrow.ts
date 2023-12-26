// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {babyjub} from 'circomlibjs';
import {Scalar} from 'ffjavascript';

import {encryptPointsElGamal} from '../base/encryption';
import {
    CommonEscrowData,
    DAOEscrowData,
    DataEscrowData,
    EscrowEncryptedPoints,
    EscrowType,
} from '../types/escrow';
import {Keypair, Point, PublicKey} from '../types/keypair';

/**
 *  Function to encrypt data for escrow.
 *
 * @param {CommonEscrowData} data - data to be encrypted.
 * @param {PublicKey} dataEscrowPublicKey - PublicKey for the escrow.
 * @param {EscrowType} escrowType - Type of the escrow.
 * @returns {Keypair} ephemeralKeypair - An ephemeral keypair.
 * @returns {EscrowEncryptedPoints} escrowEncryptedPoints - Encrypted points to
 * store in the escrow.
 */
export function encryptDataForEscrow(
    data: CommonEscrowData,
    dataEscrowPublicKey: PublicKey,
    escrowType: EscrowType,
): {
    ephemeralKeypair: Keypair;
    escrowEncryptedPoints: EscrowEncryptedPoints;
} {
    const {ephemeralKeypair, encryptedPoints} = encryptDataIntoPointsOnBJJ(
        data,
        dataEscrowPublicKey,
        escrowType,
    );

    const escrowEncryptedPoints: EscrowEncryptedPoints = [
        encryptedPoints.map((pair: Point) => pair[0]), // Y coordinates
        encryptedPoints.map((pair: Point) => pair[1]), // X coordinates
    ];

    return {
        ephemeralKeypair,
        escrowEncryptedPoints,
    };
}

function convertEscrowDataToScalars(
    data: CommonEscrowData,
    escrowType: EscrowType,
): bigint[] {
    if (escrowType === EscrowType.Zone) {
        const {zAccountID} = data as DAOEscrowData;

        return [zAccountID];
    }

    if (escrowType === EscrowType.DAO) {
        const {
            zAccountID,
            zAccountZoneId,
            utxoInOriginZoneIds,
            utxoOutTargetZoneIds,
        } = data as DAOEscrowData;

        return [
            shift16AndBOr(zAccountID, zAccountZoneId),
            shift16AndBOr(utxoInOriginZoneIds[0], utxoOutTargetZoneIds[0]),
            shift16AndBOr(utxoInOriginZoneIds[1], utxoOutTargetZoneIds[1]),
        ];
    }

    if (escrowType === EscrowType.Data) {
        const {
            zAccountID,
            zAccountZoneId,
            zAssetID,
            utxoInAmounts,
            utxoOutAmounts,
            utxoInOriginZoneIds,
            utxoOutTargetZoneIds,
        } = data as DataEscrowData;

        return [
            zAssetID,
            shift16AndBOr(zAccountID, zAccountZoneId),
            ...utxoInAmounts,
            ...utxoOutAmounts,
            shift16AndBOr(utxoInOriginZoneIds[0], utxoOutTargetZoneIds[0]),
            shift16AndBOr(utxoInOriginZoneIds[1], utxoOutTargetZoneIds[1]),
        ];
    }

    throw new Error('Invalid escrow type');
}

// Function to encrypt escrow data
function encryptDataIntoPointsOnBJJ(
    data: CommonEscrowData,
    dataEscrowPublicKey: PublicKey,
    escrowType: EscrowType,
): {
    ephemeralKeypair: Keypair;
    encryptedPoints: Point[];
} {
    const scalars = convertEscrowDataToScalars(data, escrowType);
    const points: Point[] = scalars.map(
        scalar => babyjub.mulPointEscalar(babyjub.Base8, scalar) as Point,
    );

    if (escrowType === EscrowType.Data) {
        const {utxoOutSpendingPublicKeys} = data as DataEscrowData;
        points.push(...utxoOutSpendingPublicKeys);
    }

    return encryptPointsElGamal(points, dataEscrowPublicKey);
}

// Function to shift left 16 and bitwise OR two numbers
function shift16AndBOr(num1: bigint, num2: bigint): bigint {
    return BigInt(Scalar.bor(Scalar.shiftLeft(num1, 16), num2).toString());
}
