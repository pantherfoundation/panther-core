// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {decodeTxNote} from '../../src/panther/notes';
import {
    ZAccountActivationNote,
    PrpConversionNote,
    ZTransactionNote,
    ZSwapNote,
} from '../../src/types/note';
import {TxType} from '../../src/types/transaction';

import {testData} from './data/notes';

describe('Transaction notes', () => {
    describe('#decodeTxNote', () => {
        describe('ZAccountActivationNote', () => {
            let decodedNote: ZAccountActivationNote;

            beforeAll(async () => {
                decodedNote = decodeTxNote(
                    testData.type01.content,
                    TxType.ZAccountActivation,
                ) as ZAccountActivationNote;
            });

            testData.type01.testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote[
                            testCase.field as keyof ZAccountActivationNote
                        ],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxType.ZAccountActivation),
                ).toThrowError('Invalid input');
            });
        });

        describe('PrpConversionNote', () => {
            let decodedNote3: PrpConversionNote;

            beforeAll(async () => {
                decodedNote3 = decodeTxNote(
                    testData.type03.content,
                    TxType.PrpConversion,
                ) as PrpConversionNote;
            });

            testData.type03.testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote3[testCase.field as keyof PrpConversionNote],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxType.PrpConversion),
                ).toThrowError('Invalid input');
            });
        });

        describe('ZTransactionNote', () => {
            let decodedNote4: ZTransactionNote;

            beforeAll(async () => {
                decodedNote4 = decodeTxNote(
                    testData.type04.content,
                    TxType.ZTransaction,
                ) as ZTransactionNote;
            });

            testData.type04.testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote4[testCase.field as keyof ZTransactionNote],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxType.ZTransaction),
                ).toThrowError('Invalid input');
            });
        });

        describe('ZSwapNote', () => {
            let decodedNote5: ZSwapNote;

            beforeAll(async () => {
                decodedNote5 = decodeTxNote(
                    testData.type05.content,
                    TxType.ZSwap,
                ) as ZSwapNote;
            });

            testData.type05.testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote5[testCase.field as keyof ZSwapNote],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxType.ZSwap),
                ).toThrowError('Invalid input');
            });
        });
    });
});
