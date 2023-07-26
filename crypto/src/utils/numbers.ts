// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {BigNumber, constants} from 'ethers';
import type {BigNumberish} from 'ethers';

export const sumBigNumbers = (
    arr: BigNumberish[],
    initialValue = constants.Zero,
) => {
    return arr
        .map((e: BigNumberish) => BigNumber.from(e))
        .reduce((total, e) => total.add(e), initialValue);
};
