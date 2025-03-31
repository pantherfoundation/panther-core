// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {expect} from 'chai';
import {ethers} from 'hardhat';

import {MockTransactionNoteEmitter} from '../../types/contracts';

import {
    TransactionTypes,
    generatePrivateMessage,
    generateLowLengthPrivateMessage,
    generateInvalidPrivateMessagesAndGetRevertMessages,
} from './data/samples/transactionNote.data';

describe('TransactionNoteEmitter', () => {
    let transactionNoteEmitter: MockTransactionNoteEmitter;

    before(async () => {
        const TransactionNoteEmitter = await ethers.getContractFactory(
            'MockTransactionNoteEmitter',
        );

        transactionNoteEmitter =
            (await TransactionNoteEmitter.deploy()) as MockTransactionNoteEmitter;
    });

    describe('zAccountActivation', () => {
        it('should revert if private message has low length', async () => {
            const privateMessage = generateLowLengthPrivateMessage(
                TransactionTypes.zAccountActivation,
            );

            await expect(
                transactionNoteEmitter.internalSanitizePrivateMessage(
                    privateMessage,
                    TransactionTypes.zAccountActivation,
                ),
            ).to.be.revertedWith('TN:E5');
        });

        it('should revert if private message is invalid', async () => {
            const {privateMessages, revertMessages} =
                generateInvalidPrivateMessagesAndGetRevertMessages(
                    TransactionTypes.zAccountActivation,
                );

            for (let i = 0; i < privateMessages.length; i++) {
                await expect(
                    transactionNoteEmitter.internalSanitizePrivateMessage(
                        privateMessages[i],
                        TransactionTypes.zAccountActivation,
                    ),
                ).to.be.revertedWith(revertMessages[i]);
            }
        });

        it('should not revert', async () => {
            const privateMessage = generatePrivateMessage(
                TransactionTypes.zAccountActivation,
            );

            expect(
                await transactionNoteEmitter.internalSanitizePrivateMessage(
                    privateMessage,
                    TransactionTypes.zAccountActivation,
                ),
            )
                .to.emit(transactionNoteEmitter, 'LogPrivateMessage')
                .withArgs(privateMessage);
        });
    });

    describe('prpClaim', () => {
        it('should revert if private message has low length', async () => {
            const privateMessage = generateLowLengthPrivateMessage(
                TransactionTypes.prpClaim,
            );

            await expect(
                transactionNoteEmitter.internalSanitizePrivateMessage(
                    privateMessage,
                    TransactionTypes.prpClaim,
                ),
            ).to.be.revertedWith('TN:E5');
        });

        it('should revert if private message is invalid', async () => {
            const {privateMessages, revertMessages} =
                generateInvalidPrivateMessagesAndGetRevertMessages(
                    TransactionTypes.prpClaim,
                );

            for (let i = 0; i < privateMessages.length; i++) {
                await expect(
                    transactionNoteEmitter.internalSanitizePrivateMessage(
                        privateMessages[i],
                        TransactionTypes.prpClaim,
                    ),
                ).to.be.revertedWith(revertMessages[i]);
            }
        });

        it('should not revert', async () => {
            const privateMessage = generatePrivateMessage(
                TransactionTypes.prpClaim,
            );

            expect(
                await transactionNoteEmitter.internalSanitizePrivateMessage(
                    privateMessage,
                    TransactionTypes.prpClaim,
                ),
            )
                .to.emit(transactionNoteEmitter, 'LogPrivateMessage')
                .withArgs(privateMessage);
        });
    });

    describe('prpConversion', () => {
        it('should revert if private message has low length', async () => {
            const privateMessage = generateLowLengthPrivateMessage(
                TransactionTypes.prpConversion,
            );

            await expect(
                transactionNoteEmitter.internalSanitizePrivateMessage(
                    privateMessage,
                    TransactionTypes.prpConversion,
                ),
            ).to.be.revertedWith('TN:E5');
        });

        it('should revert if private message is invalid', async () => {
            const {privateMessages, revertMessages} =
                generateInvalidPrivateMessagesAndGetRevertMessages(
                    TransactionTypes.prpConversion,
                );

            for (let i = 0; i < privateMessages.length; i++) {
                await expect(
                    transactionNoteEmitter.internalSanitizePrivateMessage(
                        privateMessages[i],
                        TransactionTypes.prpConversion,
                    ),
                ).to.be.revertedWith(revertMessages[i]);
            }
        });

        it('should not revert', async () => {
            const privateMessage = generatePrivateMessage(
                TransactionTypes.prpConversion,
            );

            expect(
                await transactionNoteEmitter.internalSanitizePrivateMessage(
                    privateMessage,
                    TransactionTypes.prpConversion,
                ),
            )
                .to.emit(transactionNoteEmitter, 'LogPrivateMessage')
                .withArgs(privateMessage);
        });
    });

    describe('main', () => {
        it('should revert if private message has low length', async () => {
            const privateMessage = generateLowLengthPrivateMessage(
                TransactionTypes.main,
            );

            await expect(
                transactionNoteEmitter.internalSanitizePrivateMessage(
                    privateMessage,
                    TransactionTypes.main,
                ),
            ).to.be.revertedWith('TN:E5');
        });

        it('should revert if message is invalid', async () => {
            const {privateMessages, revertMessages} =
                generateInvalidPrivateMessagesAndGetRevertMessages(
                    TransactionTypes.main,
                );

            for (let i = 0; i < privateMessages.length; i++) {
                await expect(
                    transactionNoteEmitter.internalSanitizePrivateMessage(
                        privateMessages[i],
                        TransactionTypes.main,
                    ),
                ).to.be.revertedWith(revertMessages[i]);
            }
        });

        it('should not revert', async () => {
            const privateMessage = generatePrivateMessage(
                TransactionTypes.main,
            );

            expect(
                await transactionNoteEmitter.internalSanitizePrivateMessage(
                    privateMessage,
                    TransactionTypes.main,
                ),
            )
                .to.emit(transactionNoteEmitter, 'LogPrivateMessage')
                .withArgs(privateMessage);
        });
    });
});
