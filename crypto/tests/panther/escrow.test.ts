// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {
    convertDataEscrowToScalars,
    encryptDataForEscrow,
} from '../../src/panther/escrow';
import {
    CommonEscrowData,
    DataEscrowData,
    EscrowType,
} from '../../src/types/escrow';
import {PublicKey} from '../../src/types/keypair';

const data: CommonEscrowData = {
    zAssetID: 0n,
    zAccountID: 33n,
    zAccountZoneId: 1n,
    zAccountNonce: 1n,
    utxoInMerkleTreeSelector: Array(2).fill(Array(32).fill(0n)),
    utxoInPathIndices: Array(2).fill(Array(32).fill(0n)),
    utxoInAmounts: [0, 0].map(BigInt),
    utxoOutAmounts: [10, 0].map(BigInt),
    utxoInOriginZoneIds: [0, 0].map(BigInt),
    utxoOutTargetZoneIds: [1, 0].map(BigInt),
    utxoOutSpendingPublicKeys: [
        [16n, 17n],
        [18n, 19n],
    ],
    ephemeralPubKey: [20n, 21n],
};

// Define a constant public key to avoid repetition
const dataEscrowPublicKey: PublicKey = [16n, 17n];

// Function to test encryptDataForEscrow to avoid repetition
function testEncryptDataForEscrow(
    escrowType: EscrowType,
    expectedLength: number,
) {
    const result = encryptDataForEscrow(data, dataEscrowPublicKey, escrowType);

    expect(typeof result).toBe('object');
    expect(result).toHaveProperty('ephemeralKeypair');
    expect(result).toHaveProperty('escrowEncryptedPoints');
    expect(result.escrowEncryptedPoints[0].length).toEqual(expectedLength);
    expect(result.escrowEncryptedPoints[1].length).toEqual(expectedLength);
}

describe('Encrypt Points for Data Escrow', () => {
    describe('data length check', () => {
        it('EscrowType.Data', () => {
            testEncryptDataForEscrow(EscrowType.Data, 11);
        });

        it('EscrowType.DAO', () => {
            testEncryptDataForEscrow(EscrowType.DAO, 1);
        });

        it('EscrowType.Zone', () => {
            testEncryptDataForEscrow(EscrowType.Zone, 1);
        });
    });

    describe('Convert scalars', () => {
        it('EscrowType.Data', () => {
            const output = convertDataEscrowToScalars(data as DataEscrowData);
            expect(output).toEqual([0n, 2162689n, 1n, 0n, 0n, 10n, 0n, 1n, 0n]);
        });
    });
});
