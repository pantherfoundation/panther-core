// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {TokenType} from './token';
import {packTokenTypeAndAddress} from './tokenTypeAndAddress';

export function generateExactInputData(
    tokenIn: string,
    tokenInType: bigint,
    tokenOut: string,
    tokenOutType: bigint,
    amountIn: bigint,
    pluginAddress: string,
    amountOutMin: bigint,
    deadline: number,
): any {
    const data = ethers.utils.solidityPack(
        ['address', 'uint96', 'uint32'],
        [pluginAddress, amountOutMin, deadline],
    );

    const tokenInTypeAndAddress = packTokenTypeAndAddress(tokenInType, tokenIn);

    const tokenOutTypeAndAddress = packTokenTypeAndAddress(
        tokenOutType,
        tokenOut,
    );

    return {
        tokenInTypeAndAddress,
        tokenOutTypeAndAddress,
        amountIn,
        data,
    };
}

export function generateExactInputSingleData(
    tokenIn: string,
    amountIn: bigint,
    tokenOut: string,
    fee: number,
    pluginAddress: string,
    deadline: number,
): any {
    const amountOutMinimum = '0';
    const sqrtPriceLimitX96 = '0';

    const data = ethers.utils.solidityPack(
        ['address', 'uint32', 'uint96', 'uint24', 'uint160'],
        [pluginAddress, deadline, amountOutMinimum, fee, sqrtPriceLimitX96],
    );

    const tokenInTypeAndAddress = packTokenTypeAndAddress(
        TokenType.Erc20,
        tokenIn,
    );

    const tokenOutTypeAndAddress = packTokenTypeAndAddress(
        TokenType.Erc20,
        tokenOut,
    );

    return {
        tokenInTypeAndAddress,
        tokenOutTypeAndAddress,
        amountIn,
        data,
    };
}
