// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {PublicKey} from './keypair';

export enum EscrowType {
    Data = 'Data',
    DAO = 'DAO',
    Zone = 'Zone',
}

export type CommonEscrowData = {
    zAccountID?: bigint;
    zAccountZoneId?: bigint;
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

export type EscrowEncryptedPoints = [bigint[], bigint[]];
