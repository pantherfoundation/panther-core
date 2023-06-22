// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar

import {BigInt, Bytes, ethereum} from '@graphprotocol/graph-ts';

export class TriadParameters {
    triadId: string;
    leafId: BigInt;
    commitments: Array<Bytes>;
    utxoData: Bytes;
    txHash: Bytes;
    block: ethereum.Block;
}
