// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock, FakeContract} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import chai, {expect} from 'chai';
import {BigNumber, Contract} from 'ethers';
import {ethers} from 'hardhat';

import {toBytes32} from '../../lib/utilities';
import {PayMaster} from '../../types/contracts';
import {UserOperationStruct} from '../../types/contracts/Account';

const ERR_SMALL_PAYMASTER_COMPENSATION = 'PM:E3';
const ERR_USER_OP_REVERTED = 'PM:E4';
const ERR_UNAUTHORIZED_BUNDLER = 'PM:E10';

const oneToken = ethers.constants.WeiPerEther;
const testCallGasCost = 1000000n;
const verificationGasCost = 100n;
const maxPreVerificationGas = 100n;
const exchangeRiskPct = 10000n;

const depositThreshold = ethers.constants.WeiPerEther.mul(100);

const bundlerConfig = {
    isEnabled: true,
    maxExtraGas: 200000n,
    gasPriceMarkupPct: 10000n,
    exchangeRiskPct: exchangeRiskPct,
};

chai.should();
chai.use(smock.matchers);

describe('Paymaster contract', function () {
    function addExtraPct(value: number, extraPct: number): number {
        return value + (value * extraPct) / HUNDRED_PERCENT;
    }

    async function paymasterFixture(entryPointAddr: string) {
        smartAccount = await smock.fake('Account');
        prpVoucherGrantor = await smock.fake('PrpVoucherController');
        const PayMasterFactory = await ethers.getContractFactory('PayMaster');

        paymaster = await PayMasterFactory.deploy(
            entryPointAddr,
            smartAccount.address,
            feeMaster.address,
            prpVoucherGrantor.address,
        );

        await paymaster.updateBundlerConfig(bundlerConfig);
        await paymaster.updateBundlerAuthorizationStatus(
            [bundlerWallet.address, entryPointSender.address],
            [true, true],
        );

        feeMaster['payOff(address)'].returns(ethers.constants.WeiPerEther);
        feeMaster['debts(address,address)'].returns();
        feeMaster.cachedNativeRateInZkp.returns(
            ethers.constants.WeiPerEther.div(100),
        );
    }

    let feeMaster: FakeContract;
    let zeroBytesCallData: string;
    // let signature: string;
    let paymasterAndData: string;
    // let nonce: number;
    let depositOp: UserOperationStruct;
    let zkpPrice;
    let feeData;
    let maxFeePerGas; // = ethers.utils.parseUnits('1', 'gwei');
    let maxPriorityFeePerGas; // = ethers.utils.parseUnits('1', 'wei');
    const HUNDRED_PERCENT = BigInt(10000);

    const zkpScale = ethers.constants.WeiPerEther;

    let paymasterCompensation: BigNumber;

    let requiredPrefund: BigNumber;
    let paymaster: Contract,
        entryPoint: Contract,
        smartAccount: Contract,
        prpVoucherGrantor: Contract;
    let ethersSigner!: SignerWithAddress;
    let entryPointSender!: SignerWithAddress;
    let bundlerWallet!: SignerWithAddress;
    let attacker!: SignerWithAddress;

    before(async function () {
        [ethersSigner, entryPointSender, bundlerWallet, attacker] =
            await ethers.getSigners();
        feeMaster = await smock.fake('FeeMaster');
    });

    context('function validatePaymasterUserOp', () => {
        before(async function () {
            await paymasterFixture(entryPointSender.address);
            zeroBytesCallData = toBytes32(0);
        });

        beforeEach(async function () {
            zkpPrice = await feeMaster.cachedNativeRateInZkp();

            paymasterAndData = ethers.utils.solidityPack(
                ['address'],
                [paymaster.address],
            );

            feeData = await ethers.provider.getFeeData();
            maxFeePerGas = feeData.maxFeePerGas;
            maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;

            depositOp = {
                sender: smartAccount.address,
                callData: zeroBytesCallData,
                verificationGasLimit: BigNumber.from(verificationGasCost),
                callGasLimit: testCallGasCost,
                paymasterAndData: paymasterAndData,
                nonce: 0,
                maxFeePerGas: maxFeePerGas,
                initCode: '0x',
                preVerificationGas: maxPreVerificationGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                signature: '0x',
            };

            requiredPrefund = BigNumber.from(
                testCallGasCost +
                    verificationGasCost * 3n +
                    maxPreVerificationGas,
            ).mul(maxFeePerGas);
        });

        it('should fail when executed not by bundler', async () => {
            await expect(
                paymaster
                    .connect(attacker)
                    .validatePaymasterUserOp(
                        depositOp,
                        ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32),
                        requiredPrefund,
                    ),
            ).to.be.revertedWith(ERR_UNAUTHORIZED_BUNDLER);
        });

        it.skip('should fail when paymasterCompensation is zero', async () => {
            paymasterCompensation = BigNumber.from(0);
            depositOp.signature = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                ['0', paymasterCompensation],
            );

            await expect(
                paymaster
                    .connect(entryPointSender)
                    .validatePaymasterUserOp(
                        depositOp,
                        ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32),
                        requiredPrefund,
                    ),
            ).to.be.revertedWith(ERR_SMALL_PAYMASTER_COMPENSATION);
        });

        it('should sponsor good paymasterCompensation', async () => {
            requiredPrefund = calculateRequiredPrefund(depositOp);
            paymasterCompensation = requiredPrefund
                .mul(zkpPrice)
                .div(zkpScale)
                .mul(4010);

            depositOp.signature = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                ['0', paymasterCompensation],
            );

            // Retrieve the cached ZKP price in its native decimal format
            const cachedZKPPrice: bigint =
                await feeMaster.cachedNativeRateInZkp();

            const requiredPaymasterCompensation: bigint = addExtraPct(
                (BigInt(requiredPrefund) * BigInt(cachedZKPPrice)) /
                    BigInt(oneToken),
                BigInt(exchangeRiskPct),
            );

            const tx = await paymaster
                .connect(entryPointSender)
                .validatePaymasterUserOp(
                    depositOp,
                    ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32),
                    requiredPrefund,
                    {
                        maxFeePerGas: maxFeePerGas,
                        maxPriorityFeePerGas: maxPriorityFeePerGas,
                    },
                );

            const receipt = await tx.wait();

            const event = receipt.events.find(
                e => e.event === 'UserOperationValidated',
            );

            expect(event).to.not.be.undefined;
            expect(event.args[1]).to.equal(requiredPrefund);
            expect(event.args[2]).to.equal(requiredPaymasterCompensation);
            expect(event.args[3]).to.equal(paymasterCompensation);
        });
    });

    context('function postOp', () => {
        enum PostOpMode {
            opSucceeded,
            opReverted,
            postOpReverted,
        }

        beforeEach(async () => {
            entryPoint = await smock.fake(entryPointInterface);
            await paymasterFixture(entryPointSender.address);
        });

        it('should accept postOp with successful operation and valid gas cost', async () => {
            const requiredTotal = ethers.utils.parseEther('1'); // 1 ether
            const actualGasCost = ethers.utils.parseEther('0.5'); // 0.5 ether
            const paymasterCompensation = ethers.utils.parseEther('0.2');
            const context = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256', 'uint256'],
                [requiredTotal, 0, paymasterCompensation],
            );

            await expect(
                paymaster
                    .connect(entryPointSender)
                    .postOp(PostOpMode.opSucceeded, context, actualGasCost),
            ).not.to.be.reverted;
        });

        it('should revert with user operation reverted mode', async () => {
            const requiredTotal = ethers.utils.parseEther('1'); // 1 ether
            const actualGasCost = ethers.utils.parseEther('0.5'); // 0.5 ether
            const paymasterCompensation = ethers.utils.parseEther('0.2');
            const context = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256', 'uint256'],
                [requiredTotal, 0, paymasterCompensation],
            );

            await expect(
                paymaster
                    .connect(entryPointSender)
                    .postOp(PostOpMode.opReverted, context, actualGasCost),
            ).to.be.revertedWith(ERR_USER_OP_REVERTED);
        });

        it('should revert with postOpReverted mode', async () => {
            const requiredTotal = ethers.utils.parseEther('1'); // 1 ether
            const actualGasCost = ethers.utils.parseEther('0.5'); // 0.5 ether
            const paymasterCompensation = ethers.utils.parseEther('0.2');
            const context = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256', 'uint256'],
                [requiredTotal, 0, paymasterCompensation],
            );

            await expect(
                paymaster
                    .connect(entryPointSender)
                    .postOp(PostOpMode.postOpReverted, context, actualGasCost),
            ).to.be.revertedWith(ERR_USER_OP_REVERTED);
        });

        it('should handle edge case with zero gas cost', async () => {
            const requiredTotal = ethers.utils.parseEther('1'); // 1 ether
            const actualGasCost = ethers.utils.parseEther('0'); // 0 ether
            const paymasterCompensation = ethers.utils.parseEther('0.2');
            const context = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256', 'uint256'],
                [requiredTotal, 0, paymasterCompensation],
            );

            await expect(
                paymaster
                    .connect(entryPointSender)
                    .postOp(PostOpMode.opSucceeded, context, actualGasCost),
            ).not.to.be.reverted;
        });
    });

    context('function claimEthAndRefundEntryPoint', () => {
        before(async function () {
            entryPoint = await smock.fake(entryPointInterface);
            await paymasterFixture(entryPoint.address);
            feeMaster.debts.returns(ethers.constants.WeiPerEther);
        });

        it('should send FeeMaster debt to EntryPoint', async () => {
            await paymaster.claimEthAndRefundEntryPoint(toBytes32(0));
            expect(feeMaster['payOff(address)']).to.have.been.calledWith(
                paymaster.address,
            );
        });

        it('should send FeeMaster debt to EntryPoint', async () => {
            await paymaster.claimEthAndRefundEntryPoint(toBytes32(0));
            expect(feeMaster['payOff(address)']).to.have.been.calledWith(
                paymaster.address,
            );
        });

        it('should not generateRewards when depositThreshold is  not configured', async () => {
            // FeeMaster debt is greater than depositThreshold
            feeMaster['debts(address,address)'].returns(
                depositThreshold.add(1),
            );

            const salt = toBytes32(0);
            await paymaster.claimEthAndRefundEntryPoint(salt);
            expect(feeMaster['payOff(address)']).to.have.been.calledWith(
                paymaster.address,
            );
            expect(prpVoucherGrantor.generateRewards).to.not.have.been.called;
        });

        it('should generateRewards when FeeMaster debt is greater than depositThreshold', async () => {
            await paymaster.updateDepositThreshold(1000n);
            // FeeMaster debt is greater than depositThreshold
            feeMaster['debts(address,address)'].returns(
                depositThreshold.add(1),
            );

            const salt = toBytes32(0);
            const GT_PAYMASTER_REFUND = '0x3002a002';
            await paymaster.claimEthAndRefundEntryPoint(salt);
            expect(feeMaster['payOff(address)']).to.have.been.calledWith(
                paymaster.address,
            );

            expect(prpVoucherGrantor.generateRewards).to.have.been.calledWith(
                salt,
                0,
                GT_PAYMASTER_REFUND,
            );
        });
    });

    context('function depositToEntryPoint via proxy', () => {
        let paymasterProxy;
        let paymasterBehindProxy;

        beforeEach(async function () {
            entryPoint = await smock.fake(entryPointInterface);
            entryPoint.getUserOpHash.returns('1n');
            await paymasterFixture(entryPoint.address);

            const EIP173ProxyWithReceive = await ethers.getContractFactory(
                'EIP173ProxyWithReceive',
            );
            paymasterProxy = await EIP173ProxyWithReceive.deploy(
                ethers.constants.AddressZero, // implementation will be changed
                ethersSigner.address,
                [],
            );

            await paymasterProxy.deployed();

            const PayMasterFactory =
                await ethers.getContractFactory('PayMaster');

            const paymasterImpl = await PayMasterFactory.deploy(
                entryPoint.address,
                smartAccount.address,
                feeMaster.address,
                prpVoucherGrantor.address,
            );

            paymasterProxy.upgradeTo(paymasterImpl.address);

            paymasterBehindProxy = PayMasterFactory.attach(
                paymasterProxy.address,
            );
        });

        it('should receive ETH when user sends funds to comtract', async () => {
            const before = await ethers.provider.getBalance(paymaster.address);

            const txData = {to: paymasterBehindProxy.address, value: oneToken};

            const tx = await ethersSigner.sendTransaction(txData);

            await tx.wait();

            const after = await ethers.provider.getBalance(
                paymasterBehindProxy.address,
            );

            await expect(after).to.eq(before.add(oneToken));
        });

        it('should send all balance to EntryPoint when depositToEntryPoint is called', async () => {
            await checkAllBalanceSentToDepositToEntryPoint(
                paymasterBehindProxy,
                entryPoint,
            );
        });
    });

    context('function depositToEntryPoint without proxy', () => {
        let paymaster: PayMaster;

        before(async function () {
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
            await checkAllBalanceSentToDepositToEntryPoint(
                paymaster,
                entryPoint,
            );
        });
    });

    async function checkAllBalanceSentToDepositToEntryPoint(
        paymaster: Contract,
        entryPoint: Contract,
    ) {
        await entryPoint.depositTo.reset();

        const previousBalance = await ethers.provider.getBalance(
            paymaster.address,
        );

        await paymaster.depositToEntryPoint({
            value: oneToken,
        });

        expect(entryPoint['depositTo(address)']).to.have.been.calledOnce;

        expect(entryPoint.depositTo).to.have.been.calledWith(paymaster.address);

        const depositToCall = entryPoint.depositTo.getCall(0);

        expect(depositToCall.value).to.equal(oneToken.add(previousBalance));
    }
});

const entryPointInterface: ContractInterface = [
    {
        inputs: [
            {
                components: [
                    {
                        internalType: 'address',
                        name: 'sender',
                        type: 'address',
                    },
                    {
                        internalType: 'uint256',
                        name: 'nonce',
                        type: 'uint256',
                    },
                    {
                        internalType: 'bytes',
                        name: 'initCode',
                        type: 'bytes',
                    },
                    {
                        internalType: 'bytes',
                        name: 'callData',
                        type: 'bytes',
                    },
                    {
                        internalType: 'uint256',
                        name: 'callGasLimit',
                        type: 'uint256',
                    },
                    {
                        internalType: 'uint256',
                        name: 'verificationGasLimit',
                        type: 'uint256',
                    },
                    {
                        internalType: 'uint256',
                        name: 'preVerificationGas',
                        type: 'uint256',
                    },
                    {
                        internalType: 'uint256',
                        name: 'maxFeePerGas',
                        type: 'uint256',
                    },
                    {
                        internalType: 'uint256',
                        name: 'maxPriorityFeePerGas',
                        type: 'uint256',
                    },
                    {
                        internalType: 'bytes',
                        name: 'paymasterAndData',
                        type: 'bytes',
                    },
                    {
                        internalType: 'bytes',
                        name: 'signature',
                        type: 'bytes',
                    },
                ],
                internalType: 'struct UserOperation',
                name: 'userOp',
                type: 'tuple',
            },
        ],
        name: 'getUserOpHash',
        outputs: [
            {
                internalType: 'bytes32',
                name: '',
                type: 'bytes32',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'account',
                type: 'address',
            },
        ],
        name: 'depositTo',
        outputs: [],
        stateMutability: 'payable',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'account',
                type: 'address',
            },
        ],
        name: 'getDepositInfo',
        outputs: [
            {
                components: [
                    {
                        internalType: 'uint112',
                        name: 'deposit',
                        type: 'uint112',
                    },
                    {
                        internalType: 'bool',
                        name: 'staked',
                        type: 'bool',
                    },
                    {
                        internalType: 'uint112',
                        name: 'stake',
                        type: 'uint112',
                    },
                    {
                        internalType: 'uint32',
                        name: 'unstakeDelaySec',
                        type: 'uint32',
                    },
                    {
                        internalType: 'uint48',
                        name: 'withdrawTime',
                        type: 'uint48',
                    },
                ],
                internalType: 'struct IStakeManager.DepositInfo',
                name: 'info',
                type: 'tuple',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                internalType: 'address',
                name: 'sender',
                type: 'address',
            },
            {
                internalType: 'uint192',
                name: 'key',
                type: 'uint192',
            },
        ],
        name: 'getNonce',
        outputs: [
            {
                internalType: 'uint256',
                name: 'nonce',
                type: 'uint256',
            },
        ],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            {
                components: [
                    {
                        internalType: 'address',
                        name: 'sender',
                        type: 'address',
                    },
                    {
                        internalType: 'uint256',
                        name: 'nonce',
                        type: 'uint256',
                    },
                    {
                        internalType: 'bytes',
                        name: 'initCode',
                        type: 'bytes',
                    },
                    {
                        internalType: 'bytes',
                        name: 'callData',
                        type: 'bytes',
                    },
                    {
                        internalType: 'uint256',
                        name: 'callGasLimit',
                        type: 'uint256',
                    },
                    {
                        internalType: 'uint256',
                        name: 'verificationGasLimit',
                        type: 'uint256',
                    },
                    {
                        internalType: 'uint256',
                        name: 'preVerificationGas',
                        type: 'uint256',
                    },
                    {
                        internalType: 'uint256',
                        name: 'maxFeePerGas',
                        type: 'uint256',
                    },
                    {
                        internalType: 'uint256',
                        name: 'maxPriorityFeePerGas',
                        type: 'uint256',
                    },
                    {
                        internalType: 'bytes',
                        name: 'paymasterAndData',
                        type: 'bytes',
                    },
                    {
                        internalType: 'bytes',
                        name: 'signature',
                        type: 'bytes',
                    },
                ],
                internalType: 'struct UserOperation',
                name: 'userOp',
                type: 'tuple',
            },
            {
                internalType: 'bytes32',
                name: '',
                type: 'bytes32',
            },
            {
                internalType: 'uint256',
                name: 'requiredPreFund',
                type: 'uint256',
            },
        ],
        name: 'validatePaymasterUserOp',
        outputs: [
            {
                internalType: 'bytes',
                name: 'context',
                type: 'bytes',
            },
            {
                internalType: 'uint256',
                name: 'validationData',
                type: 'uint256',
            },
        ],
        stateMutability: 'nonpayable',
        type: 'function',
    },
];

function calculateRequiredPrefund(depositOp: {
    callGasLimit: BigNumberish;
    verificationGasLimit: BigNumberish;
    preVerificationGas: BigNumberish;
    maxFeePerGas: BigNumberish;
}): BigNumber {
    // Convert all parameters to BigNumber
    const callGasLimit = BigNumber.from(depositOp.callGasLimit);
    const verificationGasLimit = BigNumber.from(depositOp.verificationGasLimit);
    const preVerificationGas = BigNumber.from(depositOp.preVerificationGas);
    const maxFeePerGas = BigNumber.from(depositOp.maxFeePerGas);

    // Perform calculations
    const verificationGasCost = verificationGasLimit.mul(3);
    const preVerificationGasCost = preVerificationGas.mul(maxFeePerGas);
    const requiredPrefund = callGasLimit
        .add(verificationGasCost)
        .add(preVerificationGasCost);

    return requiredPrefund;
}
