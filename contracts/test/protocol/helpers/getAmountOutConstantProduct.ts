// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumber} from 'ethers';

const getAmountOut = (
    amountIn: string,
    reserveIn: string,
    reserveOut: string,
) => {
    const numerator = BigNumber.from(amountIn).mul(reserveOut);
    const denominator = BigNumber.from(reserveIn).add(amountIn);
    const amountOut = numerator.div(denominator);

    return amountOut;
};

export {getAmountOut};
