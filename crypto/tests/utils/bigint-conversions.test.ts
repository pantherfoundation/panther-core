// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {expect} from 'chai';

import {bigintToBinaryString} from '../../src/utils/bigint-conversions';

describe.only('bigintToBinaryString', () => {
    it('should correctly convert and pad binary strings', () => {
        expect(bigintToBinaryString(BigInt(10), 4)).to.equal('0b1010');
        expect(bigintToBinaryString(BigInt(10), 8)).to.equal('0b00001010');
    });

    it('should handle zero correctly', () => {
        expect(bigintToBinaryString(BigInt(0), 4)).to.equal('0b0000');
        expect(bigintToBinaryString(BigInt(0), 8)).to.equal('0b00000000');
    });
});
