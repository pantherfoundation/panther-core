// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

export type TxNoteType1 = {
    createTime: number;
    commitment: string;
    queueId: number;
    indexInQueue: number;
    zAccountUTXOMessage: string;
};

export type TxNoteType3 = TxNoteType1 & {
    zkpAmountScaled: bigint;
    zAssetUTXOMessage: string;
    zAssetCommitmentMessage: string;
};

export type TxNoteType4 = {
    createTime: number;
    commitment: string;
    queueId: number;
    indexInQueue: number;
    zAccount: string;
    zAsset1: string;
    zAsset2: string;
    spentUTXO: string;
};
