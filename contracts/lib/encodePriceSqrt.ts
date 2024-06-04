// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {BigNumber, BigNumberish} from '@ethersproject/bignumber/lib/bignumber';
import bn from 'bignumber.js';

bn.config({EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40});

// returns the sqrt price as a 64x96
export function encodePriceSqrt(
    reserve1: BigNumberish,
    reserve0: BigNumberish,
): BigNumber {
    return BigNumber.from(
        new bn(reserve1.toString())
            .div(reserve0.toString())
            .sqrt()
            .multipliedBy(new bn(2).pow(96))
            .integerValue(3)
            .toString(),
    );
}

export function nativeFromSqrtQ96PriceAndToken(
    sqrtQ96Price: BigNumberish,
    reserve0: BigNumberish,
): BigNumber {
    return BigNumber.from(
        new bn(sqrtQ96Price.toString())
            .pow(2)
            .multipliedBy(new bn(reserve0.toString()))
            .div(new bn(2).pow(96).pow(2))
            .integerValue(3)
            .toString(),
    );
}

export function tokenFromSqrtQ96PriceAndNative(
    sqrtQ96Price: BigNumberish,
    reserve1: BigNumberish,
): BigNumber {
    return BigNumber.from(
        new bn(2)
            .pow(96)
            .pow(2)
            .multipliedBy(new bn(reserve1.toString()))
            .div(new bn(sqrtQ96Price.toString()).pow(2))
            .integerValue(3)
            .toString(),
    );
}
