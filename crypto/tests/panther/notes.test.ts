// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {
    DecodedZAccountActivationTxNote,
    decodeZAccountActivationTxNote,
    parseSegment,
} from '../../src/panther/notes';

describe('Transaction notes', () => {
    describe('#decodeZAccountActivationTxNote', () => {
        let decodedNote: DecodedZAccountActivationTxNote;
        const content =
            '0x6064F22ED7621D7F30D294FE62080B65BA0FB980F17FD7A2AAAA2D4156C63DE11C60DB011E19000057D6090625CAEF63739FD45C379EBB9162BFBD9345E821186570A1A56A056E5E5BE652354C7F961DEDBA02FCC765F306D33FB25B99B497BA9187EF889E8E583A36FA3A348237CD26FE8911698F7DA5C8627E42F0BF5B99C373480404B450D601F5537EB6';

        beforeAll(async () => {
            decodedNote = decodeZAccountActivationTxNote(content);
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
                    decodedNote[
                        testCase.field as keyof DecodedZAccountActivationTxNote
                    ],
                ).toEqual(testCase.expected);
            });
        });

        it('throws an error when input is invalid', () => {
            expect(() =>
                decodeZAccountActivationTxNote('wrong-string'),
            ).toThrowError('Invalid input');
        });
    });

    describe('#parseSegment', () => {
        const testCases = [
            {
                plaintextBinary: '0123456789abcdef',
                start: 0,
                length: 4,
                expectedType: 0x01,
                expectedMsgContent: '234567',
            },
            {
                plaintextBinary: '010203040506070809',
                start: 0,
                length: 4,
                expectedType: 5,
                expectedMsgContent: 'Invalid msgType: Expected 5, got 1',
                isError: true,
            },
            {
                plaintextBinary: '010203',
                start: 2,
                length: 2,
                expectedType: 0x03,
                expectedMsgContent: '',
            },
            {
                plaintextBinary: '0123456789abcdef',
                start: 1,
                length: 255,
                expectedType: 0x23,
                expectedMsgContent: '456789abcdef',
            },
            {
                plaintextBinary: '0123456789abcdef',
                start: 0,
                length: 2,
                expectedType: 0x01,
                expectedMsgContent: '23',
            },
            {
                plaintextBinary: 'ff456789abcdef',
                start: 0,
                length: 5,
                expectedType: 255,
                expectedMsgContent: '456789ab',
            },
        ];

        testCases.forEach(testCase => {
            it(`returns the expected message content when given valid input`, () => {
                if (testCase.isError) {
                    expect(() =>
                        parseSegment(
                            testCase.plaintextBinary,
                            testCase.start,
                            testCase.length,
                            testCase.expectedType,
                        ),
                    ).toThrowError(testCase.expectedMsgContent);
                } else {
                    const result = parseSegment(
                        testCase.plaintextBinary,
                        testCase.start,
                        testCase.length,
                        testCase.expectedType,
                    );
                    expect(result).toBe(testCase.expectedMsgContent);
                }
            });
        });
    });
});
