// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import * as fieldOperations from '../../src/base/field-operations';
import {
    convertDataEscrowToScalars,
    deriveSharedKey,
    encryptDataForEscrow,
} from '../../src/panther/escrow';
import {
    DAOEscrowData,
    DataEscrowData,
    EscrowType,
    ZoneEscrowData,
} from '../../src/types/escrow';
import {PublicKey} from '../../src/types/keypair';

import {
    createMockCommonData,
    EXPECTED_SCALARS,
    ESCROW_TYPE_MAP,
    createEncryptionExpectation,
    DEFAULT_EPHEMERAL_PUB_KEY,
    MOCKED_EPHEMERAL_RANDOM,
    ESCROW_PUBLIC_KEYS,
} from './data/escrowTestData';

//#region Test Suites
describe('Escrow System', () => {
    describe('Data Conversion', () => {
        it('converts escrow data to correct scalar array format', () => {
            const output = convertDataEscrowToScalars(
                createMockCommonData() as DataEscrowData,
            );
            expect(output).toEqual(EXPECTED_SCALARS);
        });
    });

    describe('Encryption', () => {
        Object.values(ESCROW_TYPE_MAP).forEach(
            ({key: escrowType, publicKey}) => {
                describe(`${EscrowType[escrowType]} Escrow`, () => {
                    beforeEach(() => {
                        jest.spyOn(
                            fieldOperations,
                            'generateRandomInBabyJubSubField',
                        ).mockReturnValue(MOCKED_EPHEMERAL_RANDOM[escrowType]);
                    });

                    it('generates correct encryption output', () => {
                        const result = encryptDataForEscrow(
                            createMockCommonData() as unknown as
                                | DAOEscrowData
                                | DataEscrowData
                                | ZoneEscrowData,
                            publicKey as PublicKey,
                            escrowType,
                        );

                        expect(result).toMatchObject(
                            createEncryptionExpectation(escrowType),
                        );
                    });
                });
            },
        );
    });

    describe('Ephemeral Public Key Builder', () => {
        const TEST_DATA = {
            ephemeralRandom: MOCKED_EPHEMERAL_RANDOM[EscrowType.Data],
            pubKey: ESCROW_PUBLIC_KEYS[EscrowType.Data],
            ephemeralPubKey: DEFAULT_EPHEMERAL_PUB_KEY,
            sharedPubKey: [
                12871439135712262058001002684440962908819002983015508623206745248194094676428n,
                17114886397516225242214463605558970802516242403903915116207133292790211059315n,
            ],
        };

        it('generates correct ephemeral and shared public keys', () => {
            jest.spyOn(
                fieldOperations,
                'generateRandomInBabyJubSubField',
            ).mockReturnValue(TEST_DATA.ephemeralRandom);

            const {ephemeralKeypair, sharedPubKey} = deriveSharedKey(
                TEST_DATA.pubKey as PublicKey,
            );

            expect(ephemeralKeypair.publicKey).toEqual(
                TEST_DATA.ephemeralPubKey,
            );
            expect(sharedPubKey).toEqual(TEST_DATA.sharedPubKey);
        });
    });
});
//#endregion
