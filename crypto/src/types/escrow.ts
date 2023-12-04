// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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
    utxoOutSpendingPublicKeys?: PublicKey[];
    zAssetID?: bigint;
    utxoInAmounts?: bigint[];
    utxoOutAmounts?: bigint[];
};

export type ZoneEscrowData = {
    zAccountID: bigint;
};

export type DAOEscrowData = ZoneEscrowData & {
    zAccountZoneId: bigint;
    utxoInOriginZoneIds: bigint[];
    utxoOutTargetZoneIds: bigint[];
};

export type DataEscrowData = DAOEscrowData & {
    zAssetID: bigint;
    utxoInAmounts: bigint[];
    utxoOutAmounts: bigint[];
    utxoOutSpendingPublicKeys: PublicKey[];
};

export type EscrowEncryptedPoints = [bigint[], bigint[]];
