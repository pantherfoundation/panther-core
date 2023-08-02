// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {babyjub} from 'circomlibjs';

import {SNARK_FIELD_SIZE} from './constants';

export function assert(condition: boolean, message: string) {
    if (!condition) {
        throw new Error(message || 'Assertion failed');
    }
}

export function assertInSnarkField(value: bigint, objectDescription: string) {
    assert(
        value < SNARK_FIELD_SIZE,
        `${objectDescription} is not in the BN254 field`,
    );
}

export function assertInBabyJubJubSubOrder(
    value: bigint,
    objectDescription: string,
) {
    assert(
        value < babyjub.subOrder,
        `${objectDescription} is not in the BabyJubJub suborder`,
    );
}

export function assertMaxBits(
    n: bigint,
    max: number,
    objectDescription: string,
): void {
    assert(
        n < 1n << BigInt(max),
        `${objectDescription} number exceeds ${max} bits`,
    );
}
