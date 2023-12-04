// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {encryptDataForEscrow} from '../../src/panther/escrow';
import {EscrowType} from '../../src/types/escrow';
import {PublicKey} from '../../src/types/keypair';

// Define a constant data object to avoid repetition
const data = {
    zAssetID: 1n,
    zAccountID: 2n,
    zAccountZoneId: 3n,
    utxoInAmounts: [4n, 5n],
    utxoOutAmounts: [6n, 7n],
    utxoInOriginZoneIds: [8n, 9n],
    utxoOutTargetZoneIds: [10n, 11n],
    utxoOutSpendingPublicKeys: [
        [12n, 13n],
        [14n, 15n],
    ] as PublicKey[],
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
    it('EscrowType.Data', () => {
        testEncryptDataForEscrow(EscrowType.Data, 10);
    });

    it('EscrowType.DAO', () => {
        testEncryptDataForEscrow(EscrowType.DAO, 3);
    });

    it('EscrowType.Zone', () => {
        testEncryptDataForEscrow(EscrowType.Zone, 1);
    });
});
