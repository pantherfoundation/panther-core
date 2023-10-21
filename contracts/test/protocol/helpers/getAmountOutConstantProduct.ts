// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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
