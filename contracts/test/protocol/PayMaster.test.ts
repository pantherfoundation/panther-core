// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {abi, bytecode} from '../../external/abi/EntryPoint.json';
import {callculateAndGetNonce} from '../../lib/calcAndGetNonce';
import {toBytes32} from '../../lib/utilities';
import {PayMaster} from '../../types/contracts';
import {UserOperationStruct} from '../../types/contracts/Account';

import {ADDRESS_ONE, ADDRESS_ZERO, PluginFixture} from './shared';

const oneToken = ethers.constants.WeiPerEther;

describe('Paymaster contract', function () {
    const testCallGasCost = 499210n;
    const verificationGasCost = 88000n;
    const preVerificationGasCost = 73720n;
    const maspMainGasCost = 900000n;

    let fixture: PluginFixture;
    let feeData;
    let zeroBytesCallData: string;
    let signature: string;
    let paymasterAndData: string;
    let nonce: number;
    let depositOp: UserOperationStruct;
    let zkpPrice;

    const zkpScale = ethers.constants.WeiPerEther;

    let paymasterCompensation: BigNumber;

    let requiredPrefund: BigNumber;

    context('function validatePaymasterUserOp', () => {
        before(async function () {
            fixture = new PluginFixture();
            await fixture.initFixture();
            feeData = await ethers.provider.getFeeData();
            zeroBytesCallData = toBytes32(0);
        });

        beforeEach(async function () {
            feeData = await ethers.provider.getFeeData();

            zkpPrice = await fixture.feeMaster.cachedNativeRateInZkp();

            nonce = await callculateAndGetNonce(
                zeroBytesCallData,
                fixture.smartAccount.address,
                fixture.entryPoint.address,
            );

            paymasterAndData = ethers.utils.solidityPack(
                ['address'],
                [fixture.paymasterProxy.address],
            );

            depositOp = {
                sender: fixture.smartAccount.address,
                callData: zeroBytesCallData,
                verificationGasLimit: BigNumber.from(verificationGasCost),
                callGasLimit: testCallGasCost,
                paymasterAndData: paymasterAndData,
                nonce: nonce,
                maxFeePerGas: feeData.maxFeePerGas,
                initCode: '0x',
                preVerificationGas: BigNumber.from(preVerificationGasCost),
                maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
                signature: signature,
            };

            requiredPrefund = BigNumber.from(
                testCallGasCost +
                    verificationGasCost +
                    preVerificationGasCost * 3n +
                    maspMainGasCost,
            );
        });

        it('should fail wth 0 paymasterCompensation', async () => {
            paymasterCompensation = BigNumber.from(0);
            depositOp.signature = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                ['0', paymasterCompensation],
            );

            await expect(
                fixture.paymaster.validatePaymasterUserOp(
                    depositOp,
                    ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32),
                    requiredPrefund,
                ),
            ).to.revertedWith('PM:E6');
        });

        it('should succeed with paymaterCompensation not less then requiredPrefund', async () => {
            paymasterCompensation = requiredPrefund.mul(zkpPrice).div(zkpScale);

            depositOp.signature = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                ['0', paymasterCompensation],
            );

            await expect(
                fixture.paymaster.validatePaymasterUserOp(
                    depositOp,
                    ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32),
                    requiredPrefund,
                ),
            )
                .to.emit(fixture.paymaster, 'ValidatePaymasterUserOpRequested')
                .withArgs(
                    requiredPrefund,
                    requiredPrefund.mul(zkpPrice).div(zkpScale),
                    feeData.maxFeePerGas,
                    paymasterCompensation,
                );
        });
    });

    context('function postOp', () => {
        it('should handle post-operation correctly', async function () {
            const context = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                [100, 150],
            );
            await expect(fixture.paymaster.postOp(0, context, 200))
                .to.emit(fixture.paymaster, 'UserOperationSponsored')
                .withArgs(200, 100, 150);
        });
    });

    context('function claimEthAndRefundEntryPoint', () => {
        it('should send FeeMaster debt to EntryPoint', async () => {
            const before = await fixture.entryPoint.getDepositInfo(
                fixture.paymasterProxy.address,
            );

            const debt = await fixture.feeMaster.debts(
                ADDRESS_ZERO,
                ADDRESS_ZERO,
            );

            await fixture.paymaster.claimEthAndRefundEntryPoint(toBytes32(0));

            const after = await fixture.entryPoint.getDepositInfo(
                fixture.paymasterProxy.address,
            );

            await expect(before.deposit.add(debt)).to.eq(after.deposit);
        });
    });

    context('function depositToEntryPoint via proxy', () => {
        const oneToken = ethers.constants.WeiPerEther;

        before(async function () {
            fixture = new PluginFixture();
            await fixture.initFixture();
        });

        it('should receive ETH when user sends funds to comtract', async () => {
            const before = await ethers.provider.getBalance(
                fixture.paymaster.address,
            );

            const txData = {to: fixture.paymaster.address, value: oneToken};

            const tx = await fixture.ethersSigner.sendTransaction(txData);

            await tx.wait();

            const after = await ethers.provider.getBalance(
                fixture.paymaster.address,
            );

            await expect(after).to.eq(before.add(oneToken));
        });

        it('should send all balance to EntryPoint when depositToEntryPoint is called', async () => {
            const nativeBalanceBefore = await ethers.provider.getBalance(
                fixture.paymaster.address,
            );

            const before = await fixture.entryPoint.getDepositInfo(
                fixture.paymaster.address,
            );

            const tx = await fixture.paymaster.depositToEntryPoint({
                value: oneToken,
            });

            await tx.wait();

            const after = await fixture.entryPoint.getDepositInfo(
                fixture.paymaster.address,
            );

            await expect(after.deposit).to.eq(
                before.deposit.add(nativeBalanceBefore.add(oneToken)),
            );
        });
    });

    context('function depositToEntryPoint without proxy', () => {
        let entryPoint;
        let paymaster: PayMaster;

        beforeEach(async function () {
            const factory = new ethers.ContractFactory(
                abi,
                bytecode,
                fixture.ethersSigner,
            );

            entryPoint = await factory.deploy();

            await entryPoint.deployed();

            paymaster = await (
                await ethers.getContractFactory('PayMaster')
            ).deploy(
                entryPoint.address,
                entryPoint.address,
                entryPoint.address,
                entryPoint.address,
            );
        });

        it('should receive ETH when user sends funds to comtract', async () => {
            const before = await ethers.provider.getBalance(paymaster.address);

            const txData = {to: paymaster.address, value: oneToken};

            const tx = await fixture.ethersSigner.sendTransaction(txData);

            await tx.wait();

            const after = await ethers.provider.getBalance(paymaster.address);

            await expect(after).to.eq(before.add(oneToken));
        });

        it('should send all balance to EntryPoint when depositToEntryPoint is called', async () => {
            const nativeBalanceBefore = await ethers.provider.getBalance(
                paymaster.address,
            );

            const before = await entryPoint.getDepositInfo(paymaster.address);

            const tx = await paymaster.depositToEntryPoint({value: oneToken});

            await tx.wait();

            const after = await entryPoint.getDepositInfo(paymaster.address);

            await expect(after.deposit).to.eq(
                before.deposit.add(nativeBalanceBefore.add(oneToken)),
            );
        });
    });

    context('Stake Management', () => {
        let entryPoint;
        let paymaster: PayMaster;

        beforeEach(async function () {
            const factory = new ethers.ContractFactory(
                abi,
                bytecode,
                fixture.ethersSigner,
            );

            entryPoint = await factory.deploy();

            await entryPoint.deployed();

            paymaster = await (
                await ethers.getContractFactory('PayMaster')
            ).deploy(
                entryPoint.address,
                entryPoint.address,
                entryPoint.address,
                entryPoint.address,
            );
        });

        it('should add stake', async function () {
            await paymaster.addStake(100, {
                value: ethers.utils.parseEther('1'),
            });
            const depositInfo = await entryPoint.getDepositInfo(
                paymaster.address,
            );
            expect(depositInfo.stake).to.eq(ethers.utils.parseEther('1'));
        });

        it('should unlock stake', async function () {
            await paymaster.addStake(100, {
                value: ethers.utils.parseEther('1'),
            });
            await ethers.provider.send('evm_increaseTime', [100]);
            await paymaster.unlockStake();
            const depositInfo = await entryPoint.getDepositInfo(
                paymaster.address,
            );
            expect(depositInfo.withdrawTime).to.be.gt(0);
        });

        it('should withdraw stake', async function () {
            await paymaster.addStake(100, {
                value: ethers.utils.parseEther('1'),
            });
            await paymaster.unlockStake();
            // Wait for unlock time
            await ethers.provider.send('evm_increaseTime', [100]);
            await ethers.provider.send('evm_mine', []);
            await paymaster.withdrawStake(fixture.ethersSigner.address);
            const depositInfo = await entryPoint.getDepositInfo(
                paymaster.address,
            );
            expect(depositInfo.stake).to.eq(0);
        });
    });

    context('function withdrawTo', () => {
        let entryPoint;
        let paymaster: PayMaster;

        beforeEach(async function () {
            const factory = new ethers.ContractFactory(
                abi,
                bytecode,
                fixture.ethersSigner,
            );

            entryPoint = await factory.deploy();

            await entryPoint.deployed();

            paymaster = await (
                await ethers.getContractFactory('PayMaster')
            ).deploy(
                entryPoint.address,
                entryPoint.address,
                entryPoint.address,
                entryPoint.address,
            );
        });

        it('should withdraw deposit to address', async function () {
            await paymaster.depositToEntryPoint({
                value: ethers.utils.parseEther('1'),
            });
            await paymaster.withdrawTo(
                ADDRESS_ONE,
                ethers.utils.parseEther('1'),
            );
            const balance = await ethers.provider.getBalance(ADDRESS_ONE);
            expect(balance).to.be.eq(ethers.utils.parseEther('1'));
        });
    });
});
