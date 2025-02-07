// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {babyjub, poseidon} from 'circomlibjs';

import {generateRandomInBabyJubSubField} from '../base/field-operations';
import {
    CommonEscrowData,
    DAOEscrowData,
    DataEscrowData,
    EscrowEncryptedMessages,
    EscrowType,
    ZoneEscrowData,
} from '../types/escrow';
import {Keypair, PublicKey} from '../types/keypair';
import {OPAD_MODULAR, IPAD_MODULAR, SNARK_FIELD_SIZE} from '../utils/constants';

// Constants for bit manipulation configurations
const BIT_CONFIG = {
    Z_ASSET_ID: 64,
    Z_ACCOUNT_ID: 24,
    ZONE_ID: 16,
    NONCE: 32,
    MERKLE_SELECTOR: 2,
    AMOUNT: 64,
    TARGET_ZONE: 16,
};

/**
 * Encrypts data for escrow using ephemeral key derivation and HMAC verification
 */
export function encryptDataForEscrow(
    data: CommonEscrowData,
    dataEscrowPublicKey: PublicKey,
    escrowType: EscrowType,
): {
    ephemeralKeypair: Keypair;
    encryptedMessages: EscrowEncryptedMessages;
    encryptedMessageHash: bigint;
    hmac: bigint;
} {
    const {sharedPubKey, ephemeralKeypair} =
        deriveSharedKey(dataEscrowPublicKey);
    const scalars = convertEscrowDataToScalars(data, escrowType);
    const encryptedMessages = encryptScalars(scalars, sharedPubKey);

    return {ephemeralKeypair, ...encryptedMessages};
}

/**
 * Converts escrow data to cryptographic scalars based on escrow type
 */
function convertEscrowDataToScalars(
    data: CommonEscrowData,
    escrowType: EscrowType,
): bigint[] {
    switch (escrowType) {
        case EscrowType.Zone:
        case EscrowType.DAO:
            return [
                (data as DAOEscrowData | ZoneEscrowData).ephemeralPubKey[0],
            ];
        case EscrowType.Data:
            return convertDataEscrowToScalars(data as DataEscrowData);
        default:
            throw new Error(`Unsupported escrow type: ${escrowType}`);
    }
}

/**
 * Processes DataEscrowData into cryptographic scalars for encryption
 */
export function convertDataEscrowToScalars(data: DataEscrowData): bigint[] {
    return [
        calculateCompositeBitNumber(data, [
            ['zAssetID', BIT_CONFIG.Z_ASSET_ID],
            ['zAccountID', BIT_CONFIG.Z_ACCOUNT_ID],
            ['zAccountZoneId', BIT_CONFIG.ZONE_ID],
            ['zAccountNonce', BIT_CONFIG.NONCE],
            ['utxoInMerkleTreeSelector.0', 'array'],
            ['utxoInMerkleTreeSelector.1', 'array'],
            ['utxoInPathIndices.0', 'array'],
            ['utxoInPathIndices.1', 'array'],
            ['utxoInOriginZoneIds.0', BIT_CONFIG.ZONE_ID],
            ['utxoInOriginZoneIds.1', BIT_CONFIG.ZONE_ID],
        ]),
        calculateCompositeBitNumber(data, [
            ['utxoOutTargetZoneIds.0', BIT_CONFIG.TARGET_ZONE],
            ['utxoOutTargetZoneIds.1', BIT_CONFIG.TARGET_ZONE],
            ['utxoInAmounts.0', BIT_CONFIG.AMOUNT],
            ['utxoInAmounts.1', BIT_CONFIG.AMOUNT],
        ]),
        calculateCompositeBitNumber(data, [
            ['utxoOutAmounts.0', BIT_CONFIG.AMOUNT],
            ['utxoOutAmounts.1', BIT_CONFIG.AMOUNT],
        ]),
        data.utxoOutSpendingPublicKeys[0][0],
        data.utxoOutSpendingPublicKeys[1][0],
    ];
}

/**
 * Derives shared public key using ECDH key exchange
 */
export function deriveSharedKey(publicKey: PublicKey): {
    ephemeralKeypair: Keypair;
    sharedPubKey: PublicKey;
} {
    const ephemeralRandom = generateRandomInBabyJubSubField();
    const ephemeralPubKey = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom,
    ) as PublicKey;
    const sharedPubKey = babyjub.mulPointEscalar(
        publicKey,
        ephemeralRandom,
    ) as PublicKey;

    return {
        ephemeralKeypair: {
            privateKey: ephemeralRandom,
            publicKey: ephemeralPubKey,
        },
        sharedPubKey,
    };
}

/**
 * Encrypts scalar messages with hierarchical deterministic encryption
 */
function encryptScalars(
    scalarMessages: bigint[],
    sharedPubKey: PublicKey,
): {
    encryptedMessages: bigint[];
    encryptedMessageHash: bigint;
    hmac: bigint;
} {
    const keySeed = poseidon(sharedPubKey);
    const encryptedMessages = scalarMessages.map((msg, i) =>
        encryptSingleMessage(keySeed, msg, i),
    );

    const {encryptedMessageHash, hmac} = computeMessageDigests(
        encryptedMessages,
        keySeed,
    );
    return {encryptedMessages, encryptedMessageHash, hmac};
}

/**
 * Computes HMAC-SHA256 equivalent using Poseidon hash
 */
function computeMessageDigests(
    messages: bigint[],
    keySeed: bigint,
): {encryptedMessageHash: bigint; hmac: bigint} {
    const encryptedMessageHash = poseidon(messages);
    const kMac = poseidon([keySeed, BigInt(messages.length)]);

    const innerHash = poseidon([
        snarkFieldXOR(kMac, IPAD_MODULAR),
        ...messages,
    ]);
    return {
        encryptedMessageHash,
        hmac: poseidon([snarkFieldXOR(kMac, OPAD_MODULAR), innerHash]),
    };
}

/**
 * Generic bit composition function with automatic reversal handling
 */
function calculateCompositeBitNumber(
    data: DataEscrowData,
    components: Array<[string, number | 'array']>,
): bigint {
    const binaryString = components
        .map(([path, bits]) => {
            const value = path
                .split('.')
                .reduce((obj, key) => obj[key], data as any);

            // Skip reversal for array values
            const skipReverse = bits === 'array';

            const binaryValue =
                bits === 'array'
                    ? (value as bigint[]).join('')
                    : toPaddedBinary(value, bits as number);

            return skipReverse ? binaryValue : reverseString(binaryValue);
        })
        .join('');

    return BigInt(`0b${reverseString(binaryString)}`);
}

// Helper functions
function encryptSingleMessage(
    kSeed: bigint,
    message: bigint,
    index: number,
): bigint {
    const hidingScalar = poseidon([kSeed, BigInt(index)]);
    return (message + hidingScalar) % SNARK_FIELD_SIZE;
}

function toPaddedBinary(value: bigint, bits: number): string {
    return value.toString(2).padStart(bits, '0');
}

function reverseString(str: string): string {
    return [...str].reverse().join('');
}

function snarkFieldXOR(a: bigint, b: bigint): bigint {
    const product = (a * b) % SNARK_FIELD_SIZE;
    return (
        (((a + b - 2n * product) % SNARK_FIELD_SIZE) + SNARK_FIELD_SIZE) %
        SNARK_FIELD_SIZE
    );
}
