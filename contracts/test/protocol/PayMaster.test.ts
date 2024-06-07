// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {callculateAndGetNonce} from '../../lib/calcAndGetNonce';
import {toBytes32} from '../../lib/utilities';
import {EntryPoint, PayMaster} from '../../types/contracts';
import {UserOperationStruct} from '../../types/contracts/EntryPoint';

import {ADDRESS_ZERO, PluginFixture} from './shared';

const oneToken = ethers.constants.WeiPerEther;

describe.skip('Paymaster contract', function () {
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
                fixture.entryPoint,
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
        let entryPoint: EntryPoint;
        let paymaster: PayMaster;
        let ethersSigner;

        beforeEach(async function () {
            [ethersSigner] = await ethers.getSigners();

            entryPoint = await (
                await ethers.getContractFactory('EntryPoint')
            ).deploy();
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

            const tx = await ethersSigner.sendTransaction(txData);

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
});
