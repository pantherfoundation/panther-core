// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {decodeTxNote} from '../../src/panther/notes';
import {TxNoteType1, TxNoteType3, TxNoteType4} from '../../src/types/note';
import {TxType} from '../../src/types/transaction';

import {testData} from './data/notes';

describe('Transaction notes', () => {
    describe('#decodeTxNote', () => {
        describe('Type 0x01', () => {
            let decodedNote: TxNoteType1;

            beforeAll(async () => {
                decodedNote = decodeTxNote(
                    testData.type01.content,
                    TxType.ZAccountActivation,
                ) as TxNoteType1;
            });

            testData.type01.testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote[testCase.field as keyof TxNoteType1],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxType.ZAccountActivation),
                ).toThrowError('Invalid input');
            });
        });

        describe('Type 0x03', () => {
            let decodedNote3: TxNoteType3;

            beforeAll(async () => {
                decodedNote3 = decodeTxNote(
                    testData.type03.content,
                    TxType.PrpConversion,
                ) as TxNoteType3;
            });

            testData.type03.testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote3[testCase.field as keyof TxNoteType3],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxType.PrpConversion),
                ).toThrowError('Invalid input');
            });
        });

        describe('Type 0x04', () => {
            let decodedNote4: TxNoteType4;

            beforeAll(async () => {
                decodedNote4 = decodeTxNote(
                    testData.type04.content,
                    TxType.ZTransaction,
                ) as TxNoteType4;
            });

            testData.type04.testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote4[testCase.field as keyof TxNoteType4],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxType.PrpConversion),
                ).toThrowError('Invalid input');
            });
        });
    });
});
