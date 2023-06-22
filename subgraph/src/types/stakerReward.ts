// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar

import {BigInt, Bytes} from '@graphprotocol/graph-ts';

export class AdvancedStakingRewardParameters {
    advancedStakingRewardId: string;
    creationTime: i32;
    commitments: Array<Bytes> | null;
    utxoData: Bytes | null;
    zZkpAmount: BigInt | null;
    staker: string;
}
