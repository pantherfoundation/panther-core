// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {TxType} from 'types/transaction';

export type BaseTxNote = {
    createTime: number;
    commitment: string;
    queueId: number;
    indexInQueue: number;
    zAccountUTXOMessage: string;
    txType: TxType;
};

export type ZAccountActivationNote = BaseTxNote;
export type PrpClaimingNote = BaseTxNote;
export type ZAccountRenewalNote = BaseTxNote;

export type PrpConversionNote = BaseTxNote & {
    zkpAmountScaled: bigint;
    zAssetUTXOMessage: string;
};

export type ZTransactionNote = BaseTxNote & {
    spendTime: number;
    zAssetUTXOMessages: [string, string];
    spentUTXOCommitmentMessage: string;
};

export type ZSwapNote = BaseTxNote & {
    spendTime: number;
    amountScaled: bigint;
    zAssetUTXOMessages: [string, string];
    spentUTXOCommitmentMessage: string;
};

export type TxNote =
    | ZAccountActivationNote
    | ZAccountRenewalNote
    | PrpClaimingNote
    | PrpConversionNote
    | ZTransactionNote
    | ZSwapNote;
