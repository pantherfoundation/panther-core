// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import type {BytesLike} from '@ethersproject/bytes';
import {utils} from 'ethers';

export function toBytes32(data: BytesLike): string {
    return utils.hexZeroPad(data, 32);
}

export function bigintToBytes32(data: bigint): string {
    return utils.hexZeroPad(utils.hexlify(data), 32);
}
