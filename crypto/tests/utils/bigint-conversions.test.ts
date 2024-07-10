// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

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
