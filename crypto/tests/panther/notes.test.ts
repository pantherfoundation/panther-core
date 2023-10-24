// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {TxNoteType, decodeTxNote} from '../../src/panther/notes';
import {TxNoteType1, TxNoteType3} from '../../src/types/note';

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
                ) as TxNoteType1;
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

        describe('Type 0x03', () => {
            let decodedNote3: TxNoteType3;
            const content =
                '0x606537A4136217BD9787684F97737C8ABC791FF88055DF2202B2010FF78C7957283D85AD733B00000298016338F77DF691D14155069BA88CC7254B82DC9AD7A587ACC61C91910FE27F5FFF9C7A282DD7DFEB6E794777DCAD81C44A284CAC63CBE3DCC5EF1DCC7050966382EF19D4F5D12CB30EF22544696DC0606DA32726E983A1108243008834C982E32F6FC3FDAAB6F83ACE16B60703AB122339CD689DF91E7FFC905585986436C6C818DBA92F6402C034BDB431CA2B038979DCFAA09137FCBA43DB4C13C6287C27D6A940A9ADCFB4236810AC4883468515096DD4B1811A91C822E82AD776DD8BAAB62502FA8D18853597ABE8F538';

            beforeAll(async () => {
                decodedNote3 = decodeTxNote(
                    content,
                    TxNoteType.PrpConversion,
                ) as TxNoteType3;
            });

            const testCases = [
                {field: 'createTime', expected: 1698145299},
                {
                    field: 'commitment',
                    expected:
                        '0x17BD9787684F97737C8ABC791FF88055DF2202B2010FF78C7957283D85AD733B',
                },
                {field: 'queueId', expected: 664},
                {field: 'indexInQueue', expected: 0x01},
                {
                    field: 'zAccountUTXOMessage',
                    expected:
                        '0x069BA88CC7254B82DC9AD7A587ACC61C91910FE27F5FFF9C7A282DD7DFEB6E794777DCAD81C44A284CAC63CBE3DCC5EF1DCC7050966382EF19D4F5D12CB30EF22544696DC0606DA32726E983A1108243008834C982E32F6FC3FDAAB6F83ACE16B6',
                },
                {
                    field: 'zkpAmountScaled',
                    expected: 4104888083333333333n,
                },
                {
                    field: 'zAssetUTXOMessage',
                    expected:
                        '0x0703AB122339CD689DF91E7FFC905585986436C6C818DBA92F6402C034BDB431CA2B038979DCFAA09137FCBA43DB4C13C6287C27D6A940A9ADCFB4236810AC4883468515096DD4B1811A91C822E82AD776DD8BAAB62502FA8D18853597ABE8F538',
                },
            ];

            testCases.forEach(testCase => {
                it(`decodes ${testCase.field}`, () => {
                    expect(
                        decodedNote3[testCase.field as keyof TxNoteType3],
                    ).toEqual(testCase.expected);
                });
            });

            it('throws an error when input is invalid', () => {
                expect(() =>
                    decodeTxNote('wrong-string', TxNoteType.PrpConversion),
                ).toThrowError('Invalid input');
            });
        });
    });
});
