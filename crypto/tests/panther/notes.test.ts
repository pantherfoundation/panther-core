// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {TxNoteType, decodeTxNote} from '../../src/panther/notes';
import {TxNoteType1} from '../../src/types/note';

describe('Transaction notes', () => {
    describe('#decodeTxNote', () => {
        describe('Type 0x01', () => {
            let decodedNote: TxNoteType1;
            const content =
                '0x6064F22ED7621D7F30D294FE62080B65BA0FB980F17FD7A2AAAA2D4156C63DE11C60DB011E19000057D6090625CAEF63739FD45C379EBB9162BFBD9345E821186570A1A56A056E5E5BE652354C7F961DEDBA02FCC765F306D33FB25B99B497BA9187EF889E8E583A36FA3A348237CD26FE8911698F7DA5C8627E42F0BF5B99C373480404B450D601F5537EB6';

            beforeAll(async () => {
                decodedNote = decodeTxNote(
                    content,
                    TxNoteType.ZAccountActivation,
                );
            });

            const testCases = [
                {field: 'createTime', expected: 0x64f22ed7},
                {
                    field: 'commitment',
                    expected:
                        '0x1D7F30D294FE62080B65BA0FB980F17FD7A2AAAA2D4156C63DE11C60DB011E19',
                },
                {field: 'queueId', expected: 0x57d6},
                {field: 'indexInQueue', expected: 0x09},
                {
                    field: 'zAccountUTXOMessage',
                    expected:
                        '0x0625CAEF63739FD45C379EBB9162BFBD9345E821186570A1A56A056E5E5BE652354C7F961DEDBA02FCC765F306D33FB25B99B497BA9187EF889E8E583A36FA3A348237CD26FE8911698F7DA5C8627E42F0BF5B99C373480404B450D601F5537EB6',
                },
            ];

            testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote[testCase.field as keyof TxNoteType1],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxNoteType.ZAccountActivation),
                ).toThrowError('Invalid input');
            });
        });
    });
});
