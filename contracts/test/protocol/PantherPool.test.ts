// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {SaltedLockDataStruct} from '@panther-core/dapp/src/types/contracts/Vault';
import {expect} from 'chai';
import {BigNumber, Contract} from 'ethers';
import {ethers} from 'hardhat';

import {composeExecData} from '../../lib/composeExecData';
import {
    getPoseidonT3Contract,
    getPoseidonT4Contract,
} from '../../lib/poseidonBuilder';
import {TokenType} from '../../lib/token';
import {
    TokenMock,
    VaultV1,
    PantherVerifier,
    PoseidonT3,
    PoseidonT4,
    PantherStaticTree,
    PantherTaxiTree,
    PantherFerryTree,
    PantherBusTree,
    MockPantherPoolV1,
    FeeMaster,
} from '../../types/contracts';
import {SnarkProofStruct} from '../../types/contracts/IPantherPoolV1';

import {
    generatePrivateMessage,
    TransactionTypes,
} from './data/samples/transactionNote.data';
import {ErrorMessages} from './errMsgs/PantherPoolV1ErrMsgs';
import {getBlockTimestamp} from './helpers/hardhat';
import {
    getCreateZAccountInputs,
    getPrpClaimandConversionInputs,
    getMainInputs,
    ForestTreesStruct,
} from './helpers/pantherPoolV1Inputs';

describe.only('PantherPoolV1', function () {
    let owner: SignerWithAddress,
        zAccountRegistry: SignerWithAddress,
        prpVoucherGrantor: SignerWithAddress,
        prpConverter: SignerWithAddress,
        feeMaster: FakeContract<FeeMaster>;
    let pantherStaticTree: FakeContract<PantherStaticTree>;
    let pantherTaxiTree: FakeContract<PantherTaxiTree>;
    let pantherBusTree: FakeContract<PantherBusTree>;
    let pantherFerryTree: FakeContract<PantherFerryTree>;
    let vault: VaultV1;
    let zkpToken: TokenMock;
    let pantherPool: MockPantherPoolV1;
    let verifier: FakeContract<PantherVerifier>;
    let poseidonT3: PoseidonT3;
    let poseidonT4: PoseidonT4;
    let vaultProxy: Contract;
    let privateMessage: string;
    let currentLockData: SaltedLockDataStruct;
    let stealthAddress: string;
    let forestTrees: ForestTreesStruct;

    const placeholder = BigNumber.from(0);
    const proof = {
        a: {x: placeholder, y: placeholder},
        b: {
            x: [placeholder, placeholder],
            y: [placeholder, placeholder],
        },
        c: {x: placeholder, y: placeholder},
    } as SnarkProofStruct;
    const transactionOptions = 0;

    const forestMerkleRoot = ethers.utils.id('forestMerkleRoot');
    const hexForestRoot = ethers.utils.hexlify(
        BigNumber.from(forestMerkleRoot),
    );
    const paymasterCompensation = ethers.BigNumber.from('10');
    const zkpAmountMin = ethers.utils.parseEther('10');

    before(async function () {
        [owner, zAccountRegistry, prpVoucherGrantor, prpConverter] =
            await ethers.getSigners();

        const ZkpToken = await ethers.getContractFactory('TokenMock');
        zkpToken = (await ZkpToken.deploy()) as TokenMock;

        const PoseidonT3 = await getPoseidonT3Contract();
        poseidonT3 = (await PoseidonT3.deploy()) as PoseidonT3;

        const PoseidonT4 = await getPoseidonT4Contract();
        poseidonT4 = (await PoseidonT4.deploy()) as PoseidonT4;

        feeMaster = await smock.fake('FeeMaster', {});

        feeMaster['accountFees((uint16,uint8,uint40,uint40,uint40))'].returns({
            scMiningReward: 123,
            scKycFee: 456,
            scPaymasterCompensationInNative: 789,
            scKytFees: 0,
            protocolFee: 0,
        });

        feeMaster[
            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
        ].returns({
            scMiningReward: 100,
            scKycFee: 456,
            scPaymasterCompensationInNative: 789,
            scKytFees: 0,
            protocolFee: 0,
        });

        pantherStaticTree = await smock.fake('PantherStaticTree', {});
        pantherTaxiTree = await smock.fake('PantherTaxiTree');
        pantherFerryTree = await smock.fake('PantherFerryTree');
        pantherBusTree = await smock.fake('PantherBusTree');
        verifier = await smock.fake('PantherVerifier');

        forestTrees = {
            taxiTree: pantherTaxiTree.address,
            busTree: pantherBusTree.address,
            ferryTree: pantherFerryTree.address,
        };

        const EIP173Proxy = await ethers.getContractFactory('EIP173Proxy');

        vaultProxy = await EIP173Proxy.deploy(
            ethers.constants.AddressZero,
            owner.address,
            [],
        );
    });

    beforeEach(async function () {
        verifier.verify.returns(true);

        pantherStaticTree.getRoot.returns(
            ethers.utils.id('staticTreeMerkleRoot'),
        );

        const PantherPool = await ethers.getContractFactory(
            'MockPantherPoolV1',
            {
                libraries: {
                    'contracts/common/crypto/Poseidon.sol:PoseidonT3':
                        poseidonT3.address,
                    'contracts/common/crypto/Poseidon.sol:PoseidonT4':
                        poseidonT4.address,
                },
            },
        );

        pantherPool = (await PantherPool.deploy(
            owner.address,
            zkpToken.address,
            forestTrees,
            pantherStaticTree.address,
            vaultProxy.address,
            zAccountRegistry.address,
            prpVoucherGrantor.address,
            prpConverter.address,
            feeMaster.address,
            verifier.address,
        )) as MockPantherPoolV1;

        await pantherPool.deployed();

        const Vault = await ethers.getContractFactory('VaultV1');
        vault = (await Vault.deploy(pantherPool.address)) as VaultV1;

        await vaultProxy.upgradeTo(vault.address);

        await pantherPool.internalCacheNewRoot(hexForestRoot);
    });

    function getStealthAddress() {
        const salt =
            '0xc0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fe';

        currentLockData = {
            tokenType: TokenType.Erc20,
            token: zkpToken.address,
            tokenId: 0,
            salt: salt,
            extAccount: owner.address,
            extAmount: BigNumber.from('10'),
        };

        const execData = composeExecData(currentLockData, vaultProxy.address);

        const initCode = ethers.utils.solidityPack(
            ['bytes', 'address', 'bytes'],
            [
                '0x3d6014602a3d395160601C3d3d603e80380380913d393d343d955af16026573d908181803efd5b80f300',
                zkpToken.address,
                execData,
            ],
        );

        return ethers.utils.getCreate2Address(
            vaultProxy.address,
            salt,
            ethers.utils.keccak256(initCode),
        );
    }

    describe('Deployment', function () {
        it('should set the correct address', async function () {
            expect(await pantherPool.OWNER()).to.equal(owner.address);
            expect(await pantherPool.VAULT()).to.equal(vaultProxy.address);
            expect(await pantherPool.STATIC_TREE()).to.equal(
                pantherStaticTree.address,
            );
            expect(await pantherPool.ZACCOUNT_REGISTRY()).to.equal(
                zAccountRegistry.address,
            );
            expect(await pantherPool.VERIFIER()).to.equal(verifier.address);

            expect(await pantherPool.PRP_VOUCHER_GRANTOR()).to.equal(
                prpVoucherGrantor.address,
            );
            expect(await pantherPool.PRP_CONVERTER()).to.equal(
                prpConverter.address,
            );
        });

        it('should revert for zero addresses', async function () {
            const PantherPool = await ethers.getContractFactory(
                'MockPantherPoolV1',
                {
                    libraries: {
                        'contracts/common/crypto/Poseidon.sol:PoseidonT3':
                            poseidonT3.address,
                        'contracts/common/crypto/Poseidon.sol:PoseidonT4':
                            poseidonT4.address,
                    },
                },
            );

            await expect(
                PantherPool.deploy(
                    owner.address,
                    zkpToken.address,
                    forestTrees,
                    ethers.constants.AddressZero,
                    vaultProxy.address,
                    zAccountRegistry.address,
                    prpVoucherGrantor.address,
                    prpConverter.address,
                    feeMaster.address,
                    verifier.address,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INIT);

            await expect(
                PantherPool.deploy(
                    owner.address,
                    zkpToken.address,
                    forestTrees,
                    pantherStaticTree.address,
                    vaultProxy.address,
                    ethers.constants.AddressZero,
                    prpVoucherGrantor.address,
                    prpConverter.address,
                    feeMaster.address,
                    verifier.address,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INIT);
        });
    });

    describe('#createZAccountUtxo', function () {
        privateMessage = generatePrivateMessage(
            TransactionTypes.zAccountActivation,
        );

        it('should create zAccountUtxo and increase feeMaster debt', async function () {
            expect(
                await pantherPool.feeMasterDebt(zkpToken.address),
            ).to.be.equal(BigNumber.from(0));

            await pantherPool.updateCircuitId(0x100, 1);

            const inputs = await getCreateZAccountInputs({});
            await expect(
                await pantherPool
                    .connect(zAccountRegistry)
                    .createZAccountUtxo(
                        inputs,
                        proof,
                        transactionOptions,
                        TransactionTypes.zAccountActivation,
                        paymasterCompensation,
                        privateMessage,
                    ),
            ).to.emit(pantherPool, 'TransactionNote');

            expect(
                await pantherPool.feeMasterDebt(zkpToken.address),
            ).to.be.equal(ethers.utils.parseEther('10'));
        });

        it('should revert if not called by zAccountRegistry ', async function () {
            await pantherPool.updateCircuitId(0x100, 1);
            const inputs = await getCreateZAccountInputs({});

            await expect(
                pantherPool.createZAccountUtxo(
                    inputs,
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_UNAUTHORIZED);
        });

        it('should revert if circuit id is not updated ', async function () {
            const inputs = await getCreateZAccountInputs({});

            await expect(
                pantherPool
                    .connect(zAccountRegistry)
                    .createZAccountUtxo(
                        inputs,
                        proof,
                        transactionOptions,
                        TransactionTypes.zAccountActivation,
                        paymasterCompensation,
                        privateMessage,
                    ),
            ).to.be.revertedWith(ErrorMessages.ERR_UNDEFINED_CIRCUIT);
        });

        it('should revert if the input values are passed as zero ', async function () {
            await pantherPool.updateCircuitId(0x100, 1);
            await expect(
                pantherPool.connect(zAccountRegistry).createZAccountUtxo(
                    await getCreateZAccountInputs({
                        saltHash: '0',
                    }),
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_SALT_HASH);

            await expect(
                pantherPool.connect(zAccountRegistry).createZAccountUtxo(
                    await getCreateZAccountInputs({
                        magicalConstraint: '0',
                    }),
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_MAGIC_CONSTR);

            await expect(
                pantherPool.connect(zAccountRegistry).createZAccountUtxo(
                    await getCreateZAccountInputs({
                        zAccountNullifierZone: BigNumber.from(0),
                    }),
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_NULLIFIER);

            await expect(
                pantherPool.connect(zAccountRegistry).createZAccountUtxo(
                    await getCreateZAccountInputs({
                        commitment: '0',
                    }),
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_ZACCOUNT_COMMIT);

            await expect(
                pantherPool.connect(zAccountRegistry).createZAccountUtxo(
                    await getCreateZAccountInputs({
                        kycSignedMessageHash: '0',
                    }),
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_KYC_MSG_HASH);
        });

        it('should revert if static tree root is invalid', async function () {
            await pantherPool.updateCircuitId(0x100, 1);

            await expect(
                pantherPool.connect(zAccountRegistry).createZAccountUtxo(
                    await getCreateZAccountInputs({
                        staticTreeMerkleRoot: ethers.utils.id('root'),
                    }),
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_STATIC_ROOT);
        });

        it('should revert if zAccount creation time is not valid', async function () {
            await pantherPool.updateCircuitId(0x100, 1);

            await expect(
                pantherPool.connect(zAccountRegistry).createZAccountUtxo(
                    await getCreateZAccountInputs({
                        zAccountCreateTime: BigNumber.from(0),
                    }),
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_CREATE_TIME);
        });

        it('should revert if forest tree root is invalid', async function () {
            await pantherPool.updateCircuitId(0x100, 1);
            await expect(
                pantherPool.connect(zAccountRegistry).createZAccountUtxo(
                    await getCreateZAccountInputs({
                        forestMerkleRoot: ethers.utils.id('root'),
                    }),
                    proof,
                    transactionOptions,
                    TransactionTypes.zAccountActivation,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_FOREST_ROOT);
        });

        it('should revert if the proof is not valid', async function () {
            await pantherPool.updateCircuitId(0x100, 1);
            verifier.verify.returns(false);
            await expect(
                pantherPool
                    .connect(zAccountRegistry)
                    .createZAccountUtxo(
                        await getCreateZAccountInputs({}),
                        proof,
                        transactionOptions,
                        TransactionTypes.zAccountActivation,
                        paymasterCompensation,
                        privateMessage,
                    ),
            ).to.be.revertedWith(ErrorMessages.ERR_FAILED_ZK_PROOF);
        });
    });

    describe('#accountPrp', function () {
        privateMessage = generatePrivateMessage(TransactionTypes.prpClaim);

        it('should execute account PRP', async function () {
            await pantherPool.updateCircuitId(0x103, 1);

            const inputs = await getPrpClaimandConversionInputs({});

            expect(
                await pantherPool
                    .connect(prpVoucherGrantor)
                    .accountPrp(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessage,
                    ),
            ).to.emit(pantherPool, 'TransactionNote');

            expect(
                await pantherPool.feeMasterDebt(zkpToken.address),
            ).to.be.equal(ethers.utils.parseEther('10'));
        });

        it('should revert if not called by prpVoucherGrantor ', async function () {
            await pantherPool.updateCircuitId(0x103, 1);

            const inputs = await getPrpClaimandConversionInputs({});

            await expect(
                pantherPool.accountPrp(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_UNAUTHORIZED);
        });

        it('should revert if circuit id is not updated ', async function () {
            const inputs = await getPrpClaimandConversionInputs({});

            await expect(
                pantherPool
                    .connect(prpVoucherGrantor)
                    .accountPrp(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessage,
                    ),
            ).to.be.revertedWith(ErrorMessages.ERR_UNDEFINED_CIRCUIT);
        });

        it('should revert if the input values are passed as zero ', async function () {
            await pantherPool.updateCircuitId(0x103, 1);

            await expect(
                pantherPool.connect(prpVoucherGrantor).accountPrp(
                    await getPrpClaimandConversionInputs({
                        zAccountUtxoOutCommitment: '0',
                    }),
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_ZACCOUNT_COMMIT);

            await expect(
                pantherPool.connect(prpVoucherGrantor).accountPrp(
                    await getPrpClaimandConversionInputs({
                        zAccountUtxoInNullifier: '0',
                    }),
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_NULLIFIER);
        });

        it('should revert if static tree root is invalid', async function () {
            await pantherPool.updateCircuitId(0x103, 1);

            await expect(
                pantherPool.connect(prpVoucherGrantor).accountPrp(
                    await getPrpClaimandConversionInputs({
                        staticTreeMerkleRoot: ethers.utils.id('root'),
                    }),
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_STATIC_ROOT);
        });

        it('should revert if creation time is not valid', async function () {
            await pantherPool.updateCircuitId(0x103, 1);

            await expect(
                pantherPool.connect(prpVoucherGrantor).accountPrp(
                    await getPrpClaimandConversionInputs({
                        utxoOutCreateTime: BigNumber.from(0),
                    }),
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_CREATE_TIME);
        });

        it('should revert if forest tree root is invalid', async function () {
            await pantherPool.updateCircuitId(0x103, 1);
            await expect(
                pantherPool.connect(prpVoucherGrantor).accountPrp(
                    await getPrpClaimandConversionInputs({
                        forestMerkleRoot: ethers.utils.id('root'),
                    }),
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_FOREST_ROOT);
        });
    });

    describe('#createZzkpUtxoAndSpendPrpUtxo', function () {
        privateMessage = generatePrivateMessage(TransactionTypes.prpConversion);

        it('should execute PRP Conversion', async function () {
            await pantherPool.updateCircuitId(0x104, 1);

            await zkpToken.increaseAllowance(
                vaultProxy.address,
                ethers.utils.parseEther('100'),
            );

            await zkpToken.transfer(
                prpConverter.address,
                ethers.utils.parseEther('100'),
            );
            expect(await zkpToken.balanceOf(prpConverter.address)).to.be.equal(
                ethers.utils.parseEther('100'),
            );

            await zkpToken
                .connect(prpConverter)
                .approve(vaultProxy.address, ethers.utils.parseEther('100'));

            const inputs = await getPrpClaimandConversionInputs({});

            expect(
                await pantherPool
                    .connect(prpConverter)
                    .createZzkpUtxoAndSpendPrpUtxo(
                        inputs,
                        proof,
                        transactionOptions,
                        zkpAmountMin,
                        paymasterCompensation,
                        privateMessage,
                    ),
            ).to.emit(vaultProxy, 'Locked');

            expect(
                await pantherPool.feeMasterDebt(zkpToken.address),
            ).to.be.equal(ethers.utils.parseEther('10'));
            expect(await zkpToken.balanceOf(vaultProxy.address)).to.be.equal(
                ethers.utils.parseEther('10'),
            );
        });

        it('should revert if not called by prpConverter ', async function () {
            await pantherPool.updateCircuitId(0x104, 1);

            const inputs = await getPrpClaimandConversionInputs({});

            await expect(
                pantherPool.createZzkpUtxoAndSpendPrpUtxo(
                    inputs,
                    proof,
                    transactionOptions,
                    zkpAmountMin,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_UNAUTHORIZED);
        });

        it('should revert if circuit id is not updated ', async function () {
            const inputs = await getPrpClaimandConversionInputs({});

            await expect(
                pantherPool
                    .connect(prpConverter)
                    .createZzkpUtxoAndSpendPrpUtxo(
                        inputs,
                        proof,
                        transactionOptions,
                        zkpAmountMin,
                        paymasterCompensation,
                        privateMessage,
                    ),
            ).to.be.revertedWith(ErrorMessages.ERR_UNDEFINED_CIRCUIT);
        });

        it('should revert if deposit amount is non zero ', async function () {
            await pantherPool.updateCircuitId(0x104, 1);

            const inputs = await getPrpClaimandConversionInputs({
                depositPrpAmount: BigNumber.from('10'),
            });

            await expect(
                pantherPool
                    .connect(prpConverter)
                    .createZzkpUtxoAndSpendPrpUtxo(
                        inputs,
                        proof,
                        transactionOptions,
                        zkpAmountMin,
                        paymasterCompensation,
                        privateMessage,
                    ),
            ).to.be.revertedWith(ErrorMessages.ERR_TOO_LARGE_PRP_AMOUNT);
        });
    });

    describe('#main', function () {
        it('should execute Internal main transaction ', async function () {
            await pantherPool.updateCircuitId(0x105, 1);
            privateMessage = generatePrivateMessage(TransactionTypes.main);

            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('0'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.constants.AddressZero,
                kytWithdrawSignedMessageSender: vaultProxy.address,
            });
            await pantherPool
                .connect(prpConverter)
                .main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                );
        });

        it('should withdraw native token from vault', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const extraInput = ethers.utils.solidityPack(
                ['uint32', 'uint8', 'uint96', 'bytes'],
                [
                    transactionOptions,
                    TokenType.Native,
                    paymasterCompensation,
                    privateMessage,
                ],
            );
            const calculatedExtraInputHash = BigNumber.from(
                ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
            ).mod(SNARK_FIELD_SIZE);

            const inputs = await getMainInputs({
                extraInputsHash: calculatedExtraInputHash,
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.constants.AddressZero,
                kytWithdrawSignedMessageSender: vaultProxy.address,
            });

            const withdrawAmount = inputs[2];

            const balanceOfVault = await ethers.provider.getBalance(
                vaultProxy.address,
            );

            await pantherPool.main(
                inputs,
                proof,
                transactionOptions,
                TokenType.Native,
                paymasterCompensation,
                privateMessage,
            );

            expect(
                await ethers.provider.getBalance(vaultProxy.address),
            ).to.be.equal(balanceOfVault.sub(withdrawAmount));
        });

        it('should withdraw token from vault', async function () {
            await zkpToken.transfer(vaultProxy.address, BigNumber.from('100'));
            await zkpToken.increaseAllowance(
                vaultProxy.address,
                BigNumber.from('100'),
            );
            const vaultZkpBalance = await zkpToken.balanceOf(
                vaultProxy.address,
            );
            await pantherPool.updateCircuitId(0x105, 1);
            const inputs = await getMainInputs({
                token: zkpToken.address,
                kytWithdrawSignedMessageSender: vaultProxy.address,
            });
            const withdrawAmount = inputs[2];

            await pantherPool.main(
                inputs,
                proof,
                transactionOptions,
                TokenType.Erc20,
                paymasterCompensation,
                privateMessage,
            );

            expect(await zkpToken.balanceOf(vaultProxy.address)).to.be.equal(
                vaultZkpBalance.sub(withdrawAmount),
            );
        });

        it('should withdraw token from vault with protocol fee', async function () {
            const protocolFee = 10;
            feeMaster[
                'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
            ].returns({
                scMiningReward: 100,
                scKycFee: 100,
                scPaymasterCompensationInNative: 100,
                scKytFees: 0,
                protocolFee: protocolFee,
            });

            const vaultZkpBalance = await zkpToken.balanceOf(
                vaultProxy.address,
            );
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                token: zkpToken.address,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: vaultProxy.address,
            });
            const withdrawAmount = inputs[2] - protocolFee;

            await pantherPool.main(
                inputs,
                proof,
                transactionOptions,
                TokenType.Erc20,
                paymasterCompensation,
                privateMessage,
            );

            expect(await zkpToken.balanceOf(vaultProxy.address)).to.be.equal(
                vaultZkpBalance.sub(withdrawAmount),
            );
        });

        it('should execute deposit main transaction', async function () {
            const vaultZkpBalance = await zkpToken.balanceOf(
                vaultProxy.address,
            );
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                token: zkpToken.address,
                depositPrpAmount: BigNumber.from('10'),
                withdrawPrpAmount: BigNumber.from('0'),
                kytDepositSignedMessageSender: owner.address,
                kytDepositSignedMessageReceiver: vaultProxy.address,
            });
            const depositAmount = inputs[1];

            stealthAddress = getStealthAddress();
            await zkpToken.approve(stealthAddress, depositAmount);

            await pantherPool
                .connect(owner)
                .main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                );

            expect(await zkpToken.balanceOf(vaultProxy.address)).to.be.equal(
                vaultZkpBalance.add(depositAmount),
            );
        });

        it('should revert Internal main transaction if token address is non zero ', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('0'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.Wallet.createRandom().address,
                kytWithdrawSignedMessageSender: vaultProxy.address,
            });
            await expect(
                pantherPool.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_NON_ZERO_TOKEN);
        });

        it('should revert for invalid extraInputhash ', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                extraInputsHash: BigNumber.from('0'),
            });
            await expect(
                pantherPool.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_EXTRA_INPUT_HASH);
        });

        it('should revert for invalid spendTime ', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                spendTime: (await getBlockTimestamp()) + 10,
                kytWithdrawSignedMessageSender: vaultProxy.address,
            });
            await expect(
                pantherPool.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_SPEND_TIME);
        });

        it('should revert for invalid kytDepositSignedMessageReceiver', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('10'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.Wallet.createRandom().address,
                kytDepositSignedMessageReceiver:
                    ethers.Wallet.createRandom().address,
            });
            await expect(
                pantherPool.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(
                ErrorMessages.ERR_INVALID_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER,
            );
        });

        it('should revert for invalid kytDepositSignedMessageHash', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('10'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: zkpToken.address,
                kytDepositSignedMessageReceiver: vaultProxy.address,
                kytDepositSignedMessageHash: '0',
            });
            await expect(
                pantherPool.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(
                ErrorMessages.ERR_ZERO_KYT_DEPOSIT_SIGNED_MESSAGE_HASH,
            );
        });

        it('should revert for invalid kytWithdrawSignedMessageSender ', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                token: zkpToken.address,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: owner.address,
            });

            await expect(
                pantherPool.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(
                ErrorMessages.ERR_INVALID_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER,
            );
        });

        it('should revert for invalid kytWithdrawSignedMessageHash', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                token: zkpToken.address,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: vaultProxy.address,
                kytWithdrawSignedMessageHash: '0',
            });

            await expect(
                pantherPool.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(
                ErrorMessages.ERR_ZERO_KYT_WITHDRAW_SIGNED_MESSAGE_HASH,
            );
        });

        it('should revert for duplicate kytWithdrawSignedMessageHash ', async function () {
            await pantherPool.updateCircuitId(0x105, 1);

            const inputs = await getMainInputs({
                token: zkpToken.address,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: vaultProxy.address,
                kytWithdrawSignedMessageHash: ethers.utils.id(
                    'kytWithdrawSignedMessageHash',
                ),
            });

            await pantherPool.main(
                inputs,
                proof,
                transactionOptions,
                TokenType.Erc20,
                paymasterCompensation,
                privateMessage,
            );
            inputs[7] = ethers.utils.id('randomNullifier1');
            inputs[8] = ethers.utils.id('randomNullifier2');
            inputs[9] = ethers.utils.id('nullifier');

            await expect(
                pantherPool.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith(ErrorMessages.ERR_DUPLICATED_KYT_MESSAGE_HASH);
        });
    });
});
