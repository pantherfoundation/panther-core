// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import chai, {expect} from 'chai';
import {ethers} from 'hardhat';

import {revertSnapshot, takeSnapshot} from '../../lib/hardhat';
import {MockStealthExecutor, IERC20} from '../../types/contracts';

chai.use(smock.matchers);

describe('StealthExec library', function () {
    const oneToken = ethers.constants.WeiPerEther;
    const oneEth = ethers.constants.WeiPerEther;
    const salt =
        '0xc0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fe';

    let stealthExecutor: MockStealthExecutor;
    let token: FakeContract<IERC20>;
    let user: SignerWithAddress;
    let vault: SignerWithAddress;

    let calldata: string;
    let stealthExecInitcode: string;
    let stealthCallerAddr: string;

    let snapshotId: number;

    before(async function () {
        [user, vault] = await ethers.getSigners();

        const MockStealthExecutor = await ethers.getContractFactory(
            'MockStealthExecutor',
        );
        stealthExecutor =
            (await MockStealthExecutor.deploy()) as MockStealthExecutor;

        token = await smock.fake('IERC20');

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
                '0x3d6014602a3d395160601C3d3d603e80380380913d393d343d955af16026573d908181803efd5b80f300',
                token.address,
                calldata,
            ],
        );

        stealthCallerAddr = ethers.utils.getCreate2Address(
            stealthExecutor.address,
            salt,
            ethers.utils.keccak256(stealthExecInitcode),
        );
    });

    beforeEach(async () => {
        snapshotId = await takeSnapshot();
    });

    afterEach(async () => {
        await revertSnapshot(snapshotId);
    });

    describe('before "stealthCall" called', () => {
        it('should compute deterministic stealth exec address', async () => {
            await ensureCorrectStealthCallerAddrReturned();
        });

        describe('stealthCaller address', () => {
            it('should NOT have bytecode deployed', async () => {
                await ensureEmptyBytecodeAtStealthExecAddr();
            });
        });
    });

    describe('being called "stealthCall"', () => {
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

    describe('after "stealthCall" called', () => {
        beforeEach(async () => {
            await callStealthExecAndEnsureTargetCalled();
        });

        it('should compute deterministic stealth exec address', async () => {
            await ensureCorrectStealthCallerAddrReturned();
        });

        describe('stealthCaller address', () => {
            it('should NOT have bytecode deployed', async () => {
                await ensureEmptyBytecodeAtStealthExecAddr();
            });

            it('should have zero ETH balance', async () => {
                await ensureZeroEthBalanceOfStealthExecAddr();
            });
        });

        it('should NOT allow same "stealthCall" call again', async () => {
            await expect(
                callStealthExecAndEnsureTargetCalled(),
            ).to.be.revertedWith('Create2: Failed on deploy');
        });
    });

    describe('if stealthCaller address had ETH balance before "stealthCall" call', () => {
        describe('after "stealthCall" called', () => {
            it('should leave ETH balance unchanged', async () => {
                await user.sendTransaction({
                    to: stealthCallerAddr,
                    value: oneEth,
                });
                const balanceBefore =
                    await ethers.provider.getBalance(stealthCallerAddr);
                expect(balanceBefore).to.be.equal(oneEth);

                await callStealthExecAndEnsureTargetCalled();
                const balanceAfter =
                    await ethers.provider.getBalance(stealthCallerAddr);

                expect(balanceBefore).to.be.equal(balanceAfter);
            });
        });
    });
    async function callStealthExecAndEnsureTargetCalled() {
        token.transferFrom.returns(true);
        await stealthExecutor.internalStealthCall(
            salt,
            token.address,
            calldata,
            0,
        );
        expect(token.transferFrom).to.have.been.calledWith(
            user.address,
            vault.address,
            oneToken,
        );
    }

    async function ensureCorrectStealthCallerAddrReturned() {
        const returnedAddress = await stealthExecutor.internalGetStealthAddr(
            salt,
            token.address,
            calldata,
        );
        expect(returnedAddress).to.be.equal(stealthCallerAddr);
    }
    async function ensureEmptyBytecodeAtStealthExecAddr() {
        const returnedBytecode =
            await ethers.provider.getCode(stealthCallerAddr);
        expect(returnedBytecode).to.be.equal('0x');
    }
    async function ensureZeroEthBalanceOfStealthExecAddr() {
        expect(
            (await ethers.provider.getBalance(stealthCallerAddr)).toString(),
        ).to.be.equal('0');
    }
});
