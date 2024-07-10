// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {babyjub} from 'circomlibjs';

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
        encryptedPoints.map((p: Point) => p[0]), // X coordinates
        encryptedPoints.map((p: Point) => p[1]), // Y coordinates
    ];

    return {ephemeralKeypair, escrowEncryptedPoints};
}

/**
 * Performs a bitwise OR operation after shifting the first operand.
 * @param a - First operand to be shifted.
 * @param b - Second operand.
 * @param shift - Number of bits to shift the first operand.
 * @returns The result of (a << shift) | b.
 */
function shiftAndBitwiseOr(a: bigint, b: bigint, shift: number): bigint {
    return (a << BigInt(shift)) | b;
}

/**
 * Encrypts escrow data into points on the Baby Jubjub curve.
 * @param data - The common escrow data.
 * @param dataEscrowPublicKey - Public key for the escrow.
 * @param escrowType - Type of the escrow.
 * @returns Object containing ephemeral keypair and encrypted points.
 */
function encryptDataIntoPointsOnBJJ(
    data: CommonEscrowData,
    dataEscrowPublicKey: PublicKey,
    escrowType: EscrowType,
): {ephemeralKeypair: Keypair; encryptedPoints: Point[]} {
    const scalars = convertEscrowDataToScalars(data, escrowType);
    const points: Point[] = scalars.map(
        scalar => babyjub.mulPointEscalar(babyjub.Base8, scalar) as Point,
    );

    if (escrowType === EscrowType.DAO || escrowType === EscrowType.Zone) {
        points.push((data as DAOEscrowData).ephemeralPubKey);
    } else if (escrowType === EscrowType.Data) {
        points.push(...(data as DataEscrowData).utxoOutSpendingPublicKeys);
    }

    return encryptPointsElGamal(points, dataEscrowPublicKey);
}

/**
 * Converts escrow data to scalars based on the escrow type.
 * @param data - The common escrow data.
 * @param escrowType - The type of escrow.
 * @returns An array of bigints representing the scalar values.
 * @throws Error if an invalid escrow type is provided.
 */
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
        combineAccountInfo(treeSelectors, zAccountID, zAccountZoneId),
        ...utxoInAmounts,
        ...utxoOutAmounts,
        ...combineUtxoInfo(
            leafIndices,
            utxoInOriginZoneIds,
            utxoOutTargetZoneIds,
        ),
    ];
}

/**
 * Converts binary arrays to little-endian bigints.
 * @param arrays - Array of binary arrays.
 * @returns Array of bigints.
 */
function convertToLittleEndianBigInts(arrays: bigint[][]): bigint[] {
    return arrays.map(arr => BigInt('0b' + arr.slice().reverse().join('')));
}

/**
 * Combines account information into a single bigint.
 * @param treeSelectors - Array of tree selectors of input UTXOs.
 * @param zAccountID - Account ID.
 * @param zAccountZoneId - Account zone ID.
 * @returns A bigint combining all the information.
 */
function combineAccountInfo(
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

/**
 * Combines UTXO information into an array of bigints.
 * @param leafIndices - Leaf indices of the UTXOs in the Merkle Tree.
 * @param utxoInOriginZoneIds - UTXO in origin zone IDs.
 * @param utxoOutTargetZoneIds - UTXO out target zone IDs.
 * @returns Array of bigints combining all the information.
 */
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
