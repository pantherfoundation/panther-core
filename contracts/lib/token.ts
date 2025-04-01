// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumberish} from '@ethersproject/bignumber/lib/bignumber';
import {BigNumber} from 'ethers';

export const TokenType = {
    Erc20: BigNumber.from('0x00'),
    Erc721: BigNumber.from('0x10'),
    Erc1155: BigNumber.from('0x11'),
    Native: BigNumber.from('0xFF'),
    Erc2612: BigNumber.from('0x13'),
    unknown: BigNumber.from('0x99'),
};

export const encodeTokenTypeAndAddress = (
    type: BigNumberish,
    address: BigNumberish,
): BigNumberish => {
    return BigNumber.from(type).shl(160).add(BigNumber.from(address));
};

export const decodeTokenTypeAndAddress = (
    encoded: BigNumberish,
): {type: BigNumberish; address: BigNumberish} => {
    const encodedValue = BigNumber.from(encoded);

    const type = encodedValue.shr(160);
    const address =
        '0x' +
        encodedValue
            .and(BigNumber.from('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'))
            .toHexString()
            .slice(2)
            .padStart(40, '0');

    return {type, address};
};
