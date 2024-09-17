// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {Account} from '../../types/contracts';
import {UserOperationStruct} from '../../types/contracts/Account';

import {
    ADDRESS_ONE,
    buildOp,
    BYTES32_ZERO,
    BYTES64_ZERO,
    BYTES_ONE,
} from './shared';

describe.skip('Account', () => {
    let user: SignerWithAddress;
    let wallet: Account;
    let dummyAddress: string;
    const doNothingSelector = ethers.utils
        .id('doNothing(uint256)')
        .slice(0, 10);
    let callData: string;
    const someField = 1n;

    beforeEach('deploy wallet', async () => {
        [user] = await ethers.getSigners();
        /*
        // SPDX-License-Identifier: MIT
        pragma solidity ^0.8.19;

        contract DummyContract {
            function doNothing(uint val) external pure returns (bool) {
                require(val > 0, "test error");
                    return true;
            }
        }
        */
        // Dummy contract bytecode for deployment
        const dummyContractBytecode =
            '0x608060405234801561001057600080fd5b5060be8061001f6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c8063dce1d5ba14602d575b600080fd5b603c60383660046099565b6050565b604051901515815260200160405180910390f35b600080821160915760405162461bcd60e51b815260206004820152600a6024820152693a32b9ba1032b93937b960b11b604482015260640160405180910390fd5b506001919050565b60006020828403121560aa57600080fd5b503591905056fea164736f6c6343000813000a';
        const tx = await user.sendTransaction({data: dummyContractBytecode});
        const receipt = await tx.wait();
        dummyAddress = receipt.contractAddress;

        wallet = (await (
            await ethers.getContractFactory('Account')
        ).deploy(
            [
                ADDRESS_ONE,
                dummyAddress,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
            ],
            [
                BYTES_ONE,
                doNothingSelector,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
            ],
            [0, 4, 0, 0, 0, 0, 0, 0],
        )) as Account;
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

        it('should revert when sender is not account', async () => {
            op = buildOp();
            await expect(
                wallet.validateUserOp(op, BYTES32_ZERO, 0),
            ).to.be.revertedWith('OW:E10');
        });

        it('should revert when initCode is not empty', async () => {
            op = buildOp({sender: wallet.address, initCode: BYTES32_ZERO});
            await expect(
                wallet.validateUserOp(op, BYTES32_ZERO, 0),
            ).to.be.revertedWith('OW:E1');
        });

        it('shoukd revert when callData is not executeBatchOrRevert', async () => {
            op = buildOp({sender: wallet.address, callData: '0xdeaddead'});
            await expect(
                wallet.validateUserOp(op, BYTES32_ZERO, 0),
            ).to.be.revertedWith('OW:E2');
        });

        it('should revert when signature is not 64 bytes long', async () => {
            const executeBatchOrRevertSelector = ethers.utils
                .id('executeBatchOrRevert(address[],bytes[])')
                .slice(0, 10);
            op = buildOp({
                sender: wallet.address,
                callData: executeBatchOrRevertSelector,
                signature: '0x',
            });

            await expect(
                wallet.validateUserOp(op, BYTES32_ZERO, 0),
            ).to.be.revertedWith('OW:E7');
        });

        it('should revert when call is not sponsored', async () => {
            op = buildOp({sender: wallet.address, callData: accountCalldata});

            await expect(
                wallet.validateUserOp(op, BYTES32_ZERO, 0),
            ).to.be.revertedWith('OW:E3');
        });

        it('should revert when field offset does not correspond the signature content', async () => {
            callData = ethers.utils.solidityPack(
                ['bytes4', 'bytes'],
                [
                    doNothingSelector,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256'],
                        [someField],
                    ),
                ],
            );

            accountCalldata = wallet.interface.encodeFunctionData(
                'executeBatchOrRevert',
                [[dummyAddress], [callData]],
            );

            op = buildOp({
                sender: wallet.address,
                callData: accountCalldata,
                signature: BYTES64_ZERO,
            });
            await expect(
                wallet.validateUserOp(op, BYTES32_ZERO, 0),
            ).to.be.revertedWith('OW:E4');
        });

        it('should succeed when call is registered and offset corresponds', async () => {
            const signature = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                ['0', someField],
            );

            callData = ethers.utils.solidityPack(
                ['bytes4', 'bytes'],
                [
                    doNothingSelector,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256'],
                        [someField],
                    ),
                ],
            );

            accountCalldata = wallet.interface.encodeFunctionData(
                'executeBatchOrRevert',
                [[dummyAddress], [callData]],
            );

            op = buildOp({
                sender: wallet.address,
                callData: accountCalldata,
                signature: signature,
            });
            const validationData = await wallet.callStatic.validateUserOp(
                op,
                BYTES32_ZERO,
                0,
            );
            expect(validationData).to.equal(0);
        });
    });

    describe('execute', () => {
        it('should succeed when valid', async function () {
            await expect(wallet.execute(dummyAddress, callData)).to.emit(
                wallet,
                'AccountCallExecuted',
            );
        });

        it('shpuld revert when destination reverts', async function () {
            callData = ethers.utils.solidityPack(
                ['bytes4', 'bytes'],
                [
                    doNothingSelector,
                    ethers.utils.defaultAbiCoder.encode(['uint256'], ['0']),
                ],
            );

            await expect(
                wallet.execute(dummyAddress, callData),
            ).to.be.revertedWith('test error');
        });
    });

    describe('executeBatchOrRevert', () => {
        it('should succeeds whith valid batch', async function () {
            const targets = [dummyAddress];
            callData = ethers.utils.solidityPack(
                ['bytes4', 'bytes'],
                [
                    doNothingSelector,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256'],
                        [someField],
                    ),
                ],
            );
            await expect(
                wallet.executeBatchOrRevert(targets, [callData]),
            ).to.emit(wallet, 'AccountCallExecuted');
        });

        it('shpould revert when destination reverts', async function () {
            const targets = [dummyAddress];
            callData = ethers.utils.solidityPack(
                ['bytes4', 'bytes'],
                [
                    doNothingSelector,
                    ethers.utils.defaultAbiCoder.encode(['uint256'], [0n]),
                ],
            );

            await expect(
                wallet.executeBatchOrRevert(targets, [callData]),
            ).to.be.revertedWith('test error');
        });

        it('should revert silently with random data', async function () {
            const targets = [dummyAddress];
            await expect(
                wallet.executeBatchOrRevert(targets, [BYTES64_ZERO]),
            ).to.be.revertedWith('OW:E11');
        });
    });
});
