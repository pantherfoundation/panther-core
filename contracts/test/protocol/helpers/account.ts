// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumber} from 'ethers';

import {UserOperationStruct} from '../../types/contracts/Account';

import {ADDRESS_ONE, BYTES64_ZERO} from './constants';

export function buildOp(params?: UserOperationStruct): UserOperationStruct {
    return {
        sender: params?.sender ?? ADDRESS_ONE,
        nonce: params?.nonce ?? 0,
        initCode: params?.initCode ?? '0x',
        callData: params?.callData ?? '0x',
        callGasLimit: params?.callGas ?? BigNumber.from(0),
        verificationGasLimit: params?.verificationGas ?? BigNumber.from(0),
        preVerificationGas: params?.preVerificationGas ?? BigNumber.from(0),
        maxFeePerGas: params?.maxFeePerGas ?? BigNumber.from(0),
        maxPriorityFeePerGas: params?.maxPriorityFeePerGas ?? BigNumber.from(0),
        paymasterAndData: params?.paymasterAndData ?? '0x',
        signature: params?.signature ?? BYTES64_ZERO,
    };
}
