// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import chai, {expect} from 'chai';
import {ethers} from 'hardhat';

import {MockStealthExecutor, IMockErc20} from '../../types/contracts';

chai.use(smock.matchers);

describe('StealthExec contract', function () {
    const oneToken = ethers.constants.WeiPerEther;
    const oneEth = ethers.constants.WeiPerEther;
    const salt =
        '0xc0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fe';

    let stealthExecutor: MockStealthExecutor;
    let token: FakeContract<IMockErc20>;
    let user: SignerWithAddress;
    let vault: SignerWithAddress;

    let calldata: string;
    let stealthExecInitcode: string;
    let stealthExecAddr: string;

    before(async function () {
        [user, vault] = await ethers.getSigners();

        const MockStealthExecutor = await ethers.getContractFactory(
            'MockStealthExecutor',
        );
        stealthExecutor =
            (await MockStealthExecutor.deploy()) as MockStealthExecutor;

        token = await smock.fake('IMockErc20');

        calldata = ethers.utils.solidityPack(
            ['bytes4', 'bytes'],
            [
                // bytes4(keccak256('transferFrom(address,address,uint256)'))
                '0x23b872dd',
                ethers.utils.defaultAbiCoder.encode(
                    ['address', 'address', 'uint256'],
                    [user.address, vault.address, oneToken],
                ),
            ],
        );

        stealthExecInitcode = ethers.utils.solidityPack(
            ['bytes', 'address', 'bytes'],
            [
                '0x3d6014602b3d395160601C3d3d603f80380380913d393d343d955af16026573d908181803efd5b5033ff00',
                token.address,
                calldata,
            ],
        );

        stealthExecAddr = ethers.utils.getCreate2Address(
            stealthExecutor.address,
            salt,
            ethers.utils.keccak256(stealthExecInitcode),
        );
    });

    describe('before "stealthExec" called', () => {
        it('should compute stealthExec initCode', async () => {
            await ensureCorrectReturnedInitCode();
        });

        it('should compute stealthExec address', async () => {
            const returnedAddress =
                await stealthExecutor.computeStealthExecAddress(
                    salt,
                    token.address,
                    calldata,
                );
            expect(returnedAddress.toLowerCase()).to.be.equal(
                stealthExecAddr.toLowerCase(),
            );
        });

        describe('stealthExec address', () => {
            it('should NOT have bytecode deployed', async () => {
                await ensureEmptyBytecodeAtStealthExecAddr();
            });
        });
    });

    describe('being called "stealthExec"', () => {
        beforeEach(async () => {
            await callStealthExecAndEnsureTargetCalled();
        });

        it('should CALL given address with given data', async () => {
            expect(token.transferFrom).to.have.been.calledWith(
                user.address,
                vault.address,
                oneToken,
            );
        });
    });

    describe('after "stealthExec" called', () => {
        beforeEach(async () => {
            await callStealthExecAndEnsureTargetCalled();
        });

        it('should compute stealthExec address', async () => {
            await ensureCorrectReturnedInitCode();
        });

        describe('stealthExec address', () => {
            it('should NOT have bytecode deployed', async () => {
                await ensureEmptyBytecodeAtStealthExecAddr();
            });

            it('should have zero ETH balance', async () => {
                await ensureZeroEthBalanceOfStealthExecAddr();
            });
        });

        it('should allow same "stealthExec" call again', async () => {
            await callStealthExecAndEnsureTargetCalled();
        });
    });

    describe('if stealthExecAddr had ETH balance before "stealthExec" call', () => {
        describe('after "stealthExec" called', () => {
            it('should transfer entire ETH balance to StealthExec', async () => {
                await user.sendTransaction({
                    to: stealthExecAddr,
                    value: oneEth,
                });
                const balanceBefore = await ethers.provider.getBalance(
                    stealthExecutor.address,
                );

                await callStealthExecAndEnsureTargetCalled();
                await ensureZeroEthBalanceOfStealthExecAddr();

                const balanceAfter = await ethers.provider.getBalance(
                    stealthExecutor.address,
                );
                const addition = balanceAfter.sub(balanceBefore);
                expect(addition.toString()).to.be.equal(oneEth.toString());
            });
        });
    });
    async function callStealthExecAndEnsureTargetCalled() {
        token.transferFrom.returns(true);
        await stealthExecutor.stealthExec(0, salt, token.address, calldata);
        expect(token.transferFrom).to.have.been.calledWith(
            user.address,
            vault.address,
            oneToken,
        );
    }

    async function ensureCorrectReturnedInitCode() {
        const returnedInitCode = await stealthExecutor.getStealthExecInitCode(
            token.address,
            calldata,
        );
        expect(returnedInitCode).to.be.equal(stealthExecInitcode);
    }
    async function ensureEmptyBytecodeAtStealthExecAddr() {
        const returnedBytecode = await ethers.provider.getCode(stealthExecAddr);
        expect(returnedBytecode).to.be.equal('0x');
    }
    async function ensureZeroEthBalanceOfStealthExecAddr() {
        expect(
            (await ethers.provider.getBalance(stealthExecAddr)).toString(),
        ).to.be.equal('0');
    }
});
