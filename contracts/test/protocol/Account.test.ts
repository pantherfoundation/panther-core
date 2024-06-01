// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {UserOperationStruct} from '@panther-core/dapp/src/types/contracts/Account';
import {expect} from 'chai';

import {Account} from '../../types/contracts';

import {
    ADDRESS_ONE,
    buildOp,
    BYTES_ONE,
    BYTES32_ZERO,
    BYTES64_ZERO,
} from './shared';

describe('Account', () => {
    let wallet: Account;

    beforeEach('deploy wallet', async () => {
        wallet = await (
            await ethers.getContractFactory('Account')
        ).deploy(
            [
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
            ],
            [
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
            ],
            [0, 0, 0, 0, 0, 0, 0, 0],
        );
    });

    describe('validateUserOp', () => {
        let op: UserOperationStruct;
        let accountCalldata: string;

        beforeEach('build op', () => {
            accountCalldata = wallet.interface.encodeFunctionData(
                'executeBatchOrRevert',
                [
                    [ADDRESS_ONE],
                    [
                        ethers.utils.solidityPack(
                            ['bytes4', 'bytes'],
                            ['0xdeadbeaf', BYTES64_ZERO],
                        ),
                    ],
                ],
            );
        });

        context('when sender is not account', () => {
            beforeEach('set userOp', async () => {
                op = buildOp();
            });

            it('reverts with OW:E10', async () => {
                await expect(
                    wallet.validateUserOp(op, BYTES32_ZERO, 0),
                ).to.be.revertedWith('OW:E10');
            });
        });

        context('when not empty initCode', () => {
            beforeEach('set userOp', async () => {
                op = buildOp({
                    sender: wallet.address,
                    initCode: BYTES32_ZERO,
                });
            });

            it('reverts with OW:E1', async () => {
                await expect(
                    wallet.validateUserOp(op, BYTES32_ZERO, 0),
                ).to.be.revertedWith('OW:E1');
            });
        });

        context('when not executeBatchOrRevert', () => {
            beforeEach('set sender', async () => {
                op = buildOp({
                    sender: wallet.address,
                    callData: '0xdeaddead',
                });
            });

            it('reverts with OW:E2', async () => {
                await expect(
                    wallet.validateUserOp(op, BYTES32_ZERO, 0),
                ).to.be.revertedWith('OW:E2');
            });
        });

        context('when not signature is 64 bytes len', () => {
            beforeEach('set userOp', async () => {
                const executeBatchOrRevertSelector = ethers.utils
                    .id('executeBatchOrRevert(address[],bytes[])')
                    .slice(0, 10);

                op = buildOp({
                    sender: wallet.address,
                    callData: executeBatchOrRevertSelector,
                    signature: '0x',
                });
            });

            it('reverts with OW:E7', async () => {
                await expect(
                    wallet.validateUserOp(op, BYTES32_ZERO, 0),
                ).to.be.revertedWith('OW:E7');
            });
        });

        context('when not sponsored call', () => {
            beforeEach('set userOp', async () => {
                op = buildOp({
                    sender: wallet.address,
                    callData: accountCalldata,
                });
            });

            it('reverts with OW:E3', async () => {
                await expect(
                    wallet.validateUserOp(op, BYTES32_ZERO, 0),
                ).to.be.revertedWith('OW:E3');
            });
        });
    });
});
