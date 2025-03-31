// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {PublicKey} from './keypair';

export enum EscrowType {
    Data = 'Data',
    DAO = 'DAO',
    Zone = 'Zone',
}

export type CommonEscrowData = {
    zAccountID?: bigint;
    zAccountZoneId?: bigint;
    zAccountNonce?: bigint;
    utxoInOriginZoneIds?: bigint[];
    utxoOutTargetZoneIds?: bigint[];
    zAssetID?: bigint;
    utxoInAmounts?: bigint[];
    utxoOutAmounts?: bigint[];
    utxoInMerkleTreeSelector?: bigint[][];
    utxoInPathIndices?: bigint[][];
    ephemeralPubKey?: PublicKey;

    utxoOutSpendingPublicKeys?: PublicKey[];
};

export type DAOEscrowData = {
    ephemeralPubKey: PublicKey;
};

export type ZoneEscrowData = DAOEscrowData;

export type DataEscrowData = {
    // scalar values
    zAccountID: bigint;
    zAccountZoneId: bigint;
    zAccountNonce: bigint;
    utxoInOriginZoneIds: bigint[];
    utxoOutTargetZoneIds: bigint[];
    zAssetID: bigint;
    utxoInAmounts: bigint[];
    utxoOutAmounts: bigint[];
    utxoInMerkleTreeSelector: bigint[][];
    utxoInPathIndices: bigint[][];
    // point values
    utxoOutSpendingPublicKeys: PublicKey[];
};

export type EscrowEncryptedMessages = bigint[];
