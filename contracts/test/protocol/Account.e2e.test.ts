// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {callculateAndGetNonce} from '../../lib/calcAndGetNonce';
import {composeExecData} from '../../lib/composeExecData';
import {TokenType} from '../../lib/token';
import {toBytes32} from '../../lib/utilities';
import {UserOperationStruct} from '../../types/contracts/EntryPoint';

import {sampleProof} from './data/samples/pantherPool.data';
import {
    generatePrivateMessage,
    TransactionTypes,
} from './data/samples/transactionNote.data';
import {
    composeETHEscrowStealthAddress,
    getEncodedProof,
    PluginFixture,
    setupInputFields,
    ADDRESS_ZERO,
} from './shared';

describe('Account e2e', function () {
    const zkpTransferFromCallGasCost = 69921n;
    const verificationGasCost = 88000n;
    const preVerificationGasCost = 73720n;
    const maspMainGasCost = 900000n;

    let fixture: PluginFixture;
    let feeData, totalTransactionCost;
    let orphanedWalletCallData: string;
    let encodedMaintxIndex: string;
    let paymasterAndData: string;
    let nonce: number;
    let depositOp: UserOperationStruct;
    let initCode: string;
    let execData: string;
    let stealthAddress: string;
    let currentLockData: LockDataV1Struct;
    let encodedProof: any;

    const oneToken = ethers.constants.WeiPerEther;

    const amount = 1e2;

    const salt =
        '0x00fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fe';

    const poolMainSelector = ethers.utils
        .id(
            'main(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint8,uint96,bytes)',
        )
        .slice(0, 10);

    let cachedForestRootIndex;
    let tokenType: TokenType;

    let inputs: any;
    let inputsArray: any;
    let paymasterCompensation: BigNumber;
    let privateMessage;

    context('when deposit ZKP:', () => {
        let callData;

        before(async function () {
            fixture = new PluginFixture();
            await fixture.initFixture();
            tokenType = TokenType.Erc20;
            paymasterCompensation = BigNumber.from(0);
        });

        beforeEach(async function () {
            await fixture.entryPoint.depositTo(fixture.paymasterProxy.address, {
                value: ethers.utils.parseEther('0.01'),
            });

            privateMessage = generatePrivateMessage(TransactionTypes.main);

            cachedForestRootIndex = '0';

            currentLockData = {
                tokenType: tokenType,
                token: fixture.zkpToken.address,
                tokenId: 0,
                saltHash: salt,
                extAccount: fixture.ethersSigner.address,
                extAmount: amount,
            };

            inputs = await setupInputFields(
                currentLockData,
                BigNumber.from(0),
                cachedForestRootIndex,
                privateMessage,
                fixture.vault.address,
            );

            encodedProof = getEncodedProof();

            inputsArray = Object.values(inputs);

            const hexForestRoot = ethers.utils.hexlify(
                BigNumber.from(inputs.forestMerkleRoot),
            );

            const tx =
                await fixture.pantherPool.internalCacheNewRoot(hexForestRoot);

            await tx.wait();

            composeERC20SenderStealthAddress();
        });

        it('EOA -> Account::execute -> MASP::main', async () => {
            callData = ethers.utils.solidityPack(
                ['bytes4', 'bytes'],
                [
                    poolMainSelector,
                    ethers.utils.defaultAbiCoder.encode(
                        [
                            'uint256[]',
                            '((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256))',
                            'uint32',
                            'uint8',
                            'uint96',
                            'bytes',
                        ],
                        [
                            inputsArray,
                            encodedProof,
                            cachedForestRootIndex,
                            tokenType,
                            paymasterCompensation,
                            privateMessage,
                        ],
                    ),
                ],
            );

            await fixture.zkpToken
                .connect(fixture.ethersSigner)
                .approve(stealthAddress, amount);

            await expect(
                fixture.smartAccount.execute(
                    fixture.pantherPoolV1Proxy.address,
                    callData,
                ),
            )
                // .to.be.revertedWithCustomError(fixture.entryPoint, 'FailedOp')
                // .withArgs(0, 'AA31 paymaster deposit too low-');
                .to.emit(fixture.vault, 'SaltUsed')
                .withArgs(salt);
        });
    });

    context(
        'via ERC-4337 contracts ( Account, Paymaster and EntryPoint )',
        () => {
            before(async function () {
                feeData = await ethers.provider.getFeeData();

                totalTransactionCost = BigNumber.from(
                    zkpTransferFromCallGasCost +
                        verificationGasCost +
                        preVerificationGasCost * 3n +
                        maspMainGasCost,
                );

                const bundlerChargedGasAmount = totalTransactionCost.mul(
                    feeData.maxFeePerGas,
                );

                paymasterCompensation = bundlerChargedGasAmount.mul(250);

                setOrphanedWalletCallData();

                composeERC20SenderStealthAddress();

                await fixture.erc20Token.approve(stealthAddress, oneToken);
            });

            it('should succeed', async () => {
                nonce = await callculateAndGetNonce(
                    orphanedWalletCallData,
                    fixture.smartAccount.address,
                    fixture.entryPoint,
                );

                depositOp = {
                    sender: fixture.smartAccount.address,
                    callData: orphanedWalletCallData,
                    verificationGasLimit: BigNumber.from(verificationGasCost),
                    callGasLimit: 1e5,
                    paymasterAndData: paymasterAndData,
                    nonce: nonce,
                    maxFeePerGas: feeData.maxFeePerGas,
                    initCode: '0x',
                    preVerificationGas: BigNumber.from(preVerificationGasCost),
                    maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
                    signature: encodedMaintxIndex,
                };

                await expect(
                    fixture.entryPoint.handleOps(
                        [depositOp],
                        fixture.beneficiaryAddress,
                        {
                            gasLimit: totalTransactionCost,
                        },
                    ),
                )
                    // .to.be.revertedWithCustomError(fixture.entryPoint, 'FailedOp')
                    // .withArgs(0, 'AA31 paymaster deposit too low-');
                    .to.emit(fixture.entryPoint, 'UserOperationEvent');
            });
        },
    );

    context('refund EntryPoint:', () => {
        it('should succeed', async () => {
            const before = await fixture.entryPoint.getDepositInfo(
                fixture.paymasterProxy.address,
            );

            const debt = await fixture.broker.debts(ADDRESS_ZERO, ADDRESS_ZERO);

            await fixture.paymaster.claimEthAndRefundEntryPoint(toBytes32(0));

            const after = await fixture.entryPoint.getDepositInfo(
                fixture.paymasterProxy.address,
            );

            await expect(before.deposit.add(debt)).to.eq(after.deposit);
        });
    });

    context('when deposit MATIC:', () => {
        before(async function () {
            fixture = new PluginFixture();

            await fixture.initFixture();
        });

        beforeEach(async function () {
            await fixture.entryPoint.depositTo(fixture.paymasterProxy.address, {
                value: ethers.utils.parseEther('0.01'),
            });

            privateMessage = generatePrivateMessage(TransactionTypes.main);

            tokenType = TokenType.Native;
        });

        context('by sending ETH to ETHEscrow and hitting main via EOA', () => {
            it('should succeed', async () => {
                cachedForestRootIndex = '0';

                currentLockData = {
                    tokenType: tokenType,
                    token: ADDRESS_ZERO,
                    tokenId: 0,
                    saltHash: salt,
                    extAccount: fixture.ethersSigner.address,
                    extAmount: amount,
                };

                inputs = await setupInputFields(
                    currentLockData,
                    BigNumber.from(0),
                    cachedForestRootIndex,
                    privateMessage,
                    fixture.vault.address,
                );

                const hexForestRoot = ethers.utils.hexlify(
                    BigNumber.from(inputs.forestMerkleRoot),
                );

                const tx =
                    await fixture.pantherPool.internalCacheNewRoot(
                        hexForestRoot,
                    );

                await tx.wait();

                stealthAddress = composeETHEscrowStealthAddress(
                    currentLockData,
                    fixture.vault.address,
                );

                await fixture.ethersSigner.sendTransaction({
                    to: stealthAddress,
                    value: amount,
                });

                inputsArray = Object.values(inputs);

                expect(
                    await fixture.pantherPool.main(
                        inputsArray,
                        sampleProof,
                        cachedForestRootIndex,
                        tokenType,
                        0,
                        privateMessage,
                    ),
                ).to.emit(fixture.vault, 'Locked');
            });
        });

        context(
            'by sending ETH to ETHEscrow and consume main trough bundlers',
            () => {
                it('should succeed', async () => {
                    feeData = await ethers.provider.getFeeData();

                    totalTransactionCost = BigNumber.from(
                        zkpTransferFromCallGasCost +
                            verificationGasCost +
                            preVerificationGasCost * 3n +
                            maspMainGasCost,
                    );

                    const bundlerChargedGasAmount = totalTransactionCost.mul(
                        feeData.maxFeePerGas,
                    );

                    paymasterCompensation = bundlerChargedGasAmount.mul(250);

                    currentLockData = {
                        tokenType: tokenType,
                        token: ADDRESS_ZERO,
                        tokenId: 0,
                        saltHash: salt,
                        extAccount: fixture.ethersSigner.address,
                        extAmount: amount,
                    };

                    inputs = await setupInputFields(
                        currentLockData,
                        BigNumber.from(0),
                        cachedForestRootIndex,
                        privateMessage,
                        fixture.vault.address,
                    );

                    const hexForestRoot = ethers.utils.hexlify(
                        BigNumber.from(inputs.forestMerkleRoot),
                    );

                    const tx =
                        await fixture.pantherPool.internalCacheNewRoot(
                            hexForestRoot,
                        );

                    await tx.wait();

                    stealthAddress = composeETHEscrowStealthAddress(
                        currentLockData,
                        fixture.vault.address,
                    );

                    await fixture.ethersSigner.sendTransaction({
                        to: stealthAddress,
                        value: amount,
                    });

                    setOrphanedWalletCallData();

                    nonce = await callculateAndGetNonce(
                        orphanedWalletCallData,
                        fixture.smartAccount.address,
                        fixture.entryPoint,
                    );

                    depositOp = {
                        sender: fixture.smartAccount.address,
                        callData: orphanedWalletCallData,
                        verificationGasLimit:
                            BigNumber.from(verificationGasCost),
                        callGasLimit: 1e5,
                        paymasterAndData: paymasterAndData,
                        nonce: nonce,
                        maxFeePerGas: feeData.maxFeePerGas,
                        initCode: '0x',
                        preVerificationGas: BigNumber.from(
                            preVerificationGasCost,
                        ),
                        maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
                        signature: encodedMaintxIndex,
                    };

                    await expect(
                        fixture.entryPoint.handleOps(
                            [depositOp],
                            fixture.beneficiaryAddress,
                            {
                                gasLimit: 1e7,
                            },
                        ),
                    ).to.emit(fixture.entryPoint, 'UserOperationEvent');
                });
            },
        );
    });

    function composeERC20SenderStealthAddress() {
        execData = composeExecData(currentLockData, fixture.vault.address);

        initCode = ethers.utils.solidityPack(
            ['bytes', 'address', 'bytes'],
            [
                '0x3d6014602a3d395160601C3d3d603e80380380913d393d343d955af16026573d908181803efd5b80f300',
                fixture.zkpToken.address,
                execData,
            ],
        );

        stealthAddress = ethers.utils.getCreate2Address(
            fixture.vault.address,
            inputs.saltHash,
            ethers.utils.keccak256(initCode),
        );
    }

    function setOrphanedWalletCallData() {
        inputsArray = Object.values(inputs);

        paymasterAndData = ethers.utils.solidityPack(
            ['address'],
            [fixture.paymasterProxy.address],
        );

        encodedMaintxIndex = ethers.utils.defaultAbiCoder.encode(
            ['uint256', 'uint256'],
            ['0', paymasterCompensation],
        );

        orphanedWalletCallData =
            fixture.smartAccount.interface.encodeFunctionData(
                'executeBatchOrRevert',
                [
                    [fixture.pantherPoolV1Proxy.address],
                    [
                        ethers.utils.solidityPack(
                            ['bytes4', 'bytes'],
                            [
                                poolMainSelector,
                                ethers.utils.defaultAbiCoder.encode(
                                    [
                                        'uint256[]',
                                        '((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256))',
                                        'uint32',
                                        'uint8',
                                        'uint96',
                                        'bytes',
                                    ],
                                    [
                                        inputsArray,
                                        encodedProof,
                                        cachedForestRootIndex,
                                        tokenType,
                                        paymasterCompensation,
                                        privateMessage,
                                    ],
                                ),
                            ],
                        ),
                    ],
                ],
            );
    }
});
