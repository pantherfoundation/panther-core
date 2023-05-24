import {describe, expect} from '@jest/globals';
import {Wallet} from 'ethers';

import {Keypair} from '../../lib/types/keypair';
import {generateRandomInBabyJubSubField} from '../../src/base/field-operations';
import {
    deriveRootKeypairs,
    generateSpendingChildKeypair,
    deriveKeypairFromSignature,
} from '../../src/panther/keys';
import {SNARK_FIELD_SIZE} from '../../src/utils/constants';

describe('Spending child keypair', () => {
    let spendingChildKeypair: Keypair;
    let spendingRootKeypair: Keypair;

    beforeAll(async () => {
        const randomAccount = Wallet.createRandom();
        const seedSpendingMsg = `I'm creating a spending root keypair for ${randomAccount.address}`;
        const spendingSignature = await randomAccount.signMessage(
            seedSpendingMsg,
        );
        spendingRootKeypair = deriveKeypairFromSignature(spendingSignature);

        const r = generateRandomInBabyJubSubField();
        spendingChildKeypair = generateSpendingChildKeypair(
            spendingRootKeypair.privateKey,
            r,
        );
    });

    it('should be defined', () => {
        expect(spendingChildKeypair.privateKey).toBeDefined();
        expect(spendingChildKeypair.publicKey).toBeDefined();
    });

    it('should be smaller than SNARK_FIELD_SIZE', () => {
        expect(spendingChildKeypair.privateKey < SNARK_FIELD_SIZE).toBeTruthy();
        expect(
            spendingChildKeypair.publicKey[0] < SNARK_FIELD_SIZE,
        ).toBeTruthy();
        expect(
            spendingChildKeypair.publicKey[1] < SNARK_FIELD_SIZE,
        ).toBeTruthy();
    });
});

describe('Keychain', () => {
    const randomAccount = Wallet.createRandom();

    describe('Root keypairs', () => {
        it('should be smaller than snark FIELD_SIZE', async () => {
            const {
                rootReadingKeypair,
                rootSpendingKeypair,
                storageEncryptionKeypair,
            } = await deriveRootKeypairs(randomAccount);
            [
                rootReadingKeypair,
                rootSpendingKeypair,
                storageEncryptionKeypair,
            ].forEach(keypair => {
                expect(keypair.privateKey < SNARK_FIELD_SIZE).toBeTruthy();
                expect(keypair.publicKey[0] < SNARK_FIELD_SIZE).toBeTruthy();
                expect(keypair.publicKey[1] < SNARK_FIELD_SIZE).toBeTruthy();
            });
        });

        it('should be deterministic', async () => {
            const keypairsOne = await deriveRootKeypairs(randomAccount);
            const keypairsTwo = await deriveRootKeypairs(randomAccount);

            [
                [
                    keypairsOne.rootSpendingKeypair,
                    keypairsTwo.rootSpendingKeypair,
                ],
                [
                    keypairsOne.rootReadingKeypair,
                    keypairsTwo.rootReadingKeypair,
                ],
                [
                    keypairsOne.storageEncryptionKeypair,
                    keypairsTwo.storageEncryptionKeypair,
                ],
            ].forEach(([keypairOne, keypairTwo]) => {
                expect(keypairOne.privateKey).toEqual(keypairTwo.privateKey);
                expect(keypairOne.publicKey).toEqual(keypairTwo.publicKey);
            });
        });
    });
});
