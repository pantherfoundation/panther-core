// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumber} from 'ethers';

export const MaxUint128 = BigNumber.from(2).pow(128).sub(1);

export enum FeeAmount {
    LOW = 500,
    MEDIUM = 3000,
    HIGH = 10000,
}

export async function fetchDecimals(
    tokenAddress: stringp,
    provider: ethers.providers.Provider,
) {
    const tokenContract = new ethers.Contract(
        tokenAddress,
        ERC20_ABI,
        provider,
    );
    const decimals = await tokenContract.decimals();
    return decimals;
}

export async function getTokenName(
    tokenAddress: string,
    provider: ethers.providers.Provider,
): Promise<string> {
    const tokenContract = new ethers.Contract(
        tokenAddress,
        ERC20_ABI,
        provider,
    );
    return await tokenContract.name();
}

export const ERC20_ABI = [
    'function decimals() view returns (uint8)',
    'function name() view returns (string)',
];
