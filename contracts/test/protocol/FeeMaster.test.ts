// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {impersonate, ensureMinBalance} from '../../lib/hardhat';
import {
    VaultV1,
    TokenMock,
    FeeMaster,
    MockUniswapV3Pool,
    MockPantherPoolV1andFeeMaster,
    WETH9,
    MockUniswapV3Factory,
} from '../../types/contracts';

import {revertSnapshot, takeSnapshot} from './helpers/hardhat';

describe.skip('FeeMaster contract', function () {
    let feeMaster: FeeMaster;
    let vault: VaultV1;
    let token: TokenMock;
    let wethToken: WETH9;
    let owner: SignerWithAddress,
        user: SignerWithAddress,
        payMaster: SignerWithAddress,
        pantherBusTree: SignerWithAddress,
        treasury: SignerWithAddress,
        trustProvider: SignerWithAddress,
        prpVoucherGrantor: SignerWithAddress,
        prpConverter: SignerWithAddress;
    let pantherPoolV1: MockPantherPoolV1andFeeMaster;
    let snapshot: number;
    let factory: MockUniswapV3Factory;
    let pool1Addr: string;
    let pool: MockUniswapV3Pool;

    let minerRewards: bigint;
    let expectedMinerRewards: bigint;
    let protocolFee: bigint;

    const perUtxoReward = ethers.utils.parseEther('0.1');
    const perKytFee = ethers.utils.parseEther('1');
    const kycFee = ethers.utils.parseEther('1');
    const protocolFeePercentage = 100;
    const fee = 500;

    const ZKPForOneEther = 1;
    const WETHAmount = 1; // Token1 amount
    const ZKPAmount = ZKPForOneEther * WETHAmount; // Token0 amount
    const mockSqrtPriceLimitX96 = BigInt(
        Math.sqrt(WETHAmount / ZKPAmount) * 2 ** 96,
    );

    before(async function () {
        [
            owner,
            user,
            payMaster,
            pantherBusTree,
            treasury,
            trustProvider,
            prpConverter,
            prpVoucherGrantor,
        ] = await ethers.getSigners();

        const Token = await ethers.getContractFactory('TokenMock');
        const WethToken = await ethers.getContractFactory('WETH9');
        token = (await Token.connect(owner).deploy()) as TokenMock;
        wethToken = (await WethToken.connect(owner).deploy()) as WETH9;

        const MockUniswapV3Factory = await ethers.getContractFactory(
            'MockUniswapV3Factory',
        );

        factory = await MockUniswapV3Factory.deploy();

        await factory.createPool(token.address, wethToken.address, fee);
        pool1Addr = await factory.getPool(
            token.address,
            wethToken.address,
            fee,
        );
        pool = await ethers.getContractAt('MockUniswapV3Pool', pool1Addr);
        await pool.initialize(mockSqrtPriceLimitX96);

        const PantherPoolV1 = await ethers.getContractFactory(
            'MockPantherPoolV1andFeeMaster',
        );
        pantherPoolV1 = (await PantherPoolV1.connect(owner).deploy(
            owner.address,
        )) as MockPantherPoolV1andFeeMaster;

        await pantherPoolV1.deployed();

        const Vault = await ethers.getContractFactory('VaultV1');
        vault = (await Vault.deploy(pantherPoolV1.address)) as VaultV1;

        await vault.deployed();

        const providers: providersStruct = {
            pantherPool: pantherPoolV1.address,
            pantherBusTree: pantherBusTree.address,
            paymaster: payMaster.address,
            trustProvider: trustProvider.address,
        };

        const FeeMasterContract = await ethers.getContractFactory('FeeMaster');

        feeMaster = (await FeeMasterContract.deploy(
            owner.address,
            providers,
            token.address,
            wethToken.address,
            prpConverter.address,
            prpVoucherGrantor.address,
            vault.address,
            treasury.address,
        )) as FeeMaster;

        await feeMaster.deployed();

        await pantherPoolV1.updateFeeMasterandVault(
            feeMaster.address,
            vault.address,
        );
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();
    });

    describe('Deployment', function () {
        it('should set the correct owner', async function () {
            expect(await feeMaster.OWNER()).to.equal(owner.address);
        });

        it('should set the correct Vault address', async function () {
            expect(await feeMaster.VAULT()).to.equal(vault.address);
        });
    });

    describe('updateFeeParams', function () {
        it('should update FeeParams', async function () {
            await feeMaster.updateFeeParams(
                perUtxoReward,
                perKytFee,
                kycFee,
                protocolFeePercentage,
            );

            const FeeParam = await feeMaster.feeParams();
            await expect(FeeParam.scPerUtxoReward).to.be.equal(
                perUtxoReward / 1e12,
            );
            await expect(FeeParam.scPerKytFee).to.be.equal(perKytFee / 1e12);
            await expect(FeeParam.scKycFee).to.be.equal(kycFee / 1e12);
            await expect(FeeParam.protocolFeePercentage).to.be.equal(
                protocolFeePercentage,
            );
        });

        it('should not update FeeParams if not executed by owner', async function () {
            await expect(
                feeMaster
                    .connect(user)
                    .updateFeeParams(
                        perUtxoReward,
                        perKytFee,
                        kycFee,
                        protocolFeePercentage,
                    ),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('updateProtocolZkpFeeDistributionParams', function () {
        it('should update ProtocolZkpFeeDistributionParams', async function () {
            await expect(
                feeMaster.updateProtocolZkpFeeDistributionParams(10, 1000),
            )
                .to.emit(feeMaster, 'ProtocolZkpFeeDistributionParamsUpdated')
                .withArgs(10, 1000);
        });

        it('should not update ProtocolZkpFeeDistributionParams if not executed by owner', async function () {
            await expect(
                feeMaster
                    .connect(user)
                    .updateProtocolZkpFeeDistributionParams(10, 1000),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('addPool', function () {
        it('should execute addPool', async function () {
            await expect(
                feeMaster.addPool(
                    pool1Addr,
                    token.address,
                    ethers.constants.AddressZero,
                ),
            )
                .to.emit(feeMaster, 'PoolUpdated')
                .withArgs(pool1Addr, true);
        });

        it('should not addPool if not executed by owner', async function () {
            await expect(
                feeMaster
                    .connect(user)
                    .addPool(
                        pool1Addr,
                        token.address,
                        ethers.constants.AddressZero,
                    ),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('updateTwapPeriod', function () {
        it('should execute updateTwapPeriod', async function () {
            await expect(feeMaster.updateTwapPeriod(30))
                .to.emit(feeMaster, 'TwapPeriodUpdated')
                .withArgs(30);
        });

        it('should not updateTwapPeriod if not executed by owner', async function () {
            await expect(
                feeMaster.connect(user).updateTwapPeriod(60),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should revert if the TwapPeriod is zero', async function () {
            await expect(feeMaster.updateTwapPeriod(0)).to.be.revertedWith(
                'zero twap',
            );
        });
    });

    describe('updatePool', function () {
        it('should execute updatePool', async function () {
            await expect(
                feeMaster.updatePool(
                    pool1Addr,
                    ethers.constants.AddressZero,
                    token.address,
                    false,
                ),
            )
                .to.emit(feeMaster, 'PoolUpdated')
                .withArgs(pool1Addr, false);

            await revertSnapshot(snapshot);
        });

        it('should not updatePool if not executed by owner', async function () {
            await expect(
                feeMaster
                    .connect(user)
                    .updatePool(
                        pool1Addr,
                        ethers.constants.AddressZero,
                        token.address,
                        false,
                    ),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('updateDonations', function () {
        it('should execute updateDonations', async function () {
            await expect(
                feeMaster.updateDonations(
                    [261, 256, 259, 260, 262],
                    [
                        ethers.utils.parseEther('10'),
                        ethers.utils.parseEther('1'),
                        ethers.utils.parseEther('1'),
                        ethers.utils.parseEther('1'),
                        ethers.utils.parseEther('1'),
                    ],
                ),
            ).to.emit(feeMaster, 'DonationsUpdated');

            const FeeParam = await feeMaster.donations(261);
            await expect(FeeParam).to.be.equal(ethers.utils.parseEther('10'));
        });

        it('should not updateDonations if not executed by owner', async function () {
            await expect(
                feeMaster.connect(user).updateDonations([4], [10000000]),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should revert if the length mismatch', async function () {
            await expect(
                feeMaster.updateDonations(
                    [261, 256, 259, 260],
                    [
                        ethers.utils.parseEther('10'),
                        ethers.utils.parseEther('1'),
                        ethers.utils.parseEther('1'),
                    ],
                ),
            ).to.be.revertedWith('mismatch length');
        });
    });

    describe('updateNativeTokenReserveTarget', function () {
        it('should execute updateNativeTokenReserveTarget', async function () {
            await expect(
                feeMaster.updateNativeTokenReserveTarget(
                    ethers.utils.parseEther('10'),
                ),
            ).to.emit(feeMaster, 'NativeTokenReserveTargetUpdated');

            await expect(
                await feeMaster.nativeTokenReserveTarget(),
            ).to.be.equal(ethers.utils.parseEther('10'));
        });

        it('should not updateNativeTokenReserveTarget if not executed by owner', async function () {
            await expect(
                feeMaster
                    .connect(user)
                    .updateNativeTokenReserveTarget(
                        ethers.utils.parseEther('10'),
                    ),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('increaseNativeTokenReserves', function () {
        it('should execute increaseNativeTokenReserves', async function () {
            await expect(
                feeMaster.increaseNativeTokenReserves({
                    value: ethers.utils.parseEther('10'),
                }),
            ).to.emit(feeMaster, 'NativeTokenReserveUpdated');

            const vaultBal = await ethers.provider.getBalance(vault.address);
            const debt = await pantherPoolV1.feeMasterDebt(
                ethers.constants.AddressZero,
            );

            await expect(vaultBal).to.be.equal(debt);
        });

        it('should not increaseNativeTokenReserves if not executed by owner', async function () {
            await expect(
                feeMaster.connect(user).increaseNativeTokenReserves(),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should revert if the value is not greater than zero', async function () {
            await expect(
                feeMaster.increaseNativeTokenReserves(),
            ).to.be.revertedWith('invalid amount');
        });
    });

    describe('increaseZkpTokenDonations', function () {
        it('should execute increaseZkpTokenDonations', async function () {
            await feeMaster.connect(owner).approveVaultToTransferZkp();
            await token.approve(owner.address, ethers.utils.parseEther('10'));

            await token.transferFrom(
                owner.address,
                feeMaster.address,
                ethers.utils.parseEther('10'),
            );
            await feeMaster.increaseZkpTokenDonations(
                ethers.utils.parseEther('10'),
            );

            expect(await feeMaster.zkpTokenDonationReserve()).to.be.equal(
                ethers.utils.parseEther('10'),
            );
            expect(
                await pantherPoolV1.feeMasterDebt(token.address),
            ).to.be.equal(ethers.utils.parseEther('10'));
        });

        it('should not increaseZkpTokenDonations if not executed by owner', async function () {
            await expect(
                feeMaster
                    .connect(user)
                    .increaseZkpTokenDonations(ethers.utils.parseEther('10')),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('accountFees', function () {
        describe('Main transaction', function () {
            it('should execute accountFees for main transaction', async function () {
                const feeData: FeeData = {
                    txType: 261, // TT_MAIN_TRANSACTION value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 0,
                    scChargedZkpAmount: 2500000,
                };
                const assetData: AssetData = {
                    tokenAddress: token.address,
                    depositAmount: ethers.utils.parseEther('100'),
                    withdrawAmount: ethers.utils.parseEther('0.1'),
                };
                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                ](feeData, assetData);

                if (assetData.withdrawAmount > 0) {
                    protocolFee = await feeMaster.debts(
                        pantherPoolV1.address,
                        token.address,
                    );
                    const expectedProtocolFee =
                        (assetData.withdrawAmount * protocolFeePercentage) /
                        (100 * 100);
                    await expect(protocolFee).to.be.equal(expectedProtocolFee);
                }

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                let expectedKytFee = BigInt(0);
                if (assetData.depositAmount > 0) {
                    expectedKytFee += BigInt(perKytFee);
                }

                if (assetData.withdrawAmount > 0) {
                    expectedKytFee += BigInt(perKytFee);
                }

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );
                const allocatedZKPFee =
                    expectedKytFee + BigInt(feeData.scPaymasterZkpFee * 1e12);
                expectedMinerRewards =
                    BigInt(feeData.scChargedZkpAmount * 1e12) - allocatedZKPFee;

                await expect(minerRewards).to.be.equal(expectedMinerRewards);
            });

            it('should execute accountFees with zkp donations', async function () {
                const initialDonationReserve =
                    await feeMaster.zkpTokenDonationReserve();

                const DonationAmt = await feeMaster.donations(261);

                const feeData: FeeData = {
                    txType: 261, // TT_MAIN_TRANSACTION value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 10000000,
                    scChargedZkpAmount: 2500000,
                };
                const assetData: AssetData = {
                    tokenAddress: token.address,
                    depositAmount: ethers.utils.parseEther('100'),
                    withdrawAmount: ethers.utils.parseEther('0.1'),
                };
                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                ](feeData, assetData);

                if (assetData.withdrawAmount > 0) {
                    const expectedProtocolFee =
                        BigInt(protocolFee) +
                        BigInt(
                            (assetData.withdrawAmount * protocolFeePercentage) /
                                (100 * 100),
                        );

                    protocolFee = await feeMaster.debts(
                        pantherPoolV1.address,
                        token.address,
                    );
                    await expect(protocolFee).to.be.equal(expectedProtocolFee);
                }

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                let expectedKytFee = BigInt(0);
                if (assetData.depositAmount > 0) {
                    expectedKytFee += BigInt(perKytFee);
                }

                if (assetData.withdrawAmount > 0) {
                    expectedKytFee += BigInt(perKytFee);
                }

                const allocatedZKPFee =
                    expectedKytFee + BigInt(feeData.scPaymasterZkpFee * 1e12);
                expectedMinerRewards =
                    BigInt(minerRewards) +
                    BigInt(feeData.scChargedZkpAmount * 1e12) -
                    allocatedZKPFee;

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );

                expect(minerRewards).to.be.equal(expectedMinerRewards);

                expect(await feeMaster.zkpTokenDonationReserve()).to.be.equal(
                    initialDonationReserve.sub(DonationAmt),
                );
            });

            it('should revert if ZkpDonationReserve is zero ', async function () {
                const feeData: FeeData = {
                    txType: 261, // TT_MAIN_TRANSACTION value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 10000000,
                    scChargedZkpAmount: 2500000,
                };
                const assetData: AssetData = {
                    tokenAddress: token.address,
                    depositAmount: ethers.utils.parseEther('100'),
                    withdrawAmount: ethers.utils.parseEther('0.1'),
                };

                await expect(
                    feeMaster[
                        'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                    ](feeData, assetData),
                ).to.be.revertedWith('not enough donation reserve');

                await revertSnapshot(snapshot);
            });

            it('should revert for invalid donation amount ', async function () {
                const feeData: FeeData = {
                    txType: 261, // TT_MAIN_TRANSACTION value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 10000, //invalid donation amount
                    scChargedZkpAmount: 2500000,
                };
                const assetData: AssetData = {
                    tokenAddress: token.address,
                    depositAmount: ethers.utils.parseEther('100'),
                    withdrawAmount: ethers.utils.parseEther('0.1'),
                };

                await expect(
                    feeMaster[
                        'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                    ](feeData, assetData),
                ).to.be.revertedWith('invalid donation amount');
            });

            it('should revert for invalid donation amount ', async function () {
                const feeData: FeeData = {
                    txType: 261, // TT_MAIN_TRANSACTION value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 10000,
                    scChargedZkpAmount: 0,
                };
                const assetData: AssetData = {
                    tokenAddress: token.address,
                    depositAmount: ethers.utils.parseEther('100'),
                    withdrawAmount: ethers.utils.parseEther('0.1'),
                };

                await expect(
                    feeMaster[
                        'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                    ](feeData, assetData),
                ).to.be.revertedWith('zero charged zkp');
            });
        });

        describe('ZAccount Activation', function () {
            it('should execute accountFees for ZAccount activation', async function () {
                const feeData: FeeData = {
                    txType: 256, // TT_ZACCOUNT_ACTIVATION value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 0,
                    scChargedZkpAmount: 2500000,
                };

                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40))'
                ](feeData);

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                const allocatedZKPFee =
                    BigInt(kycFee) + BigInt(feeData.scPaymasterZkpFee * 1e12);

                expectedMinerRewards =
                    BigInt(minerRewards) +
                    (BigInt(feeData.scChargedZkpAmount * 1e12) -
                        BigInt(allocatedZKPFee));

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );

                expect(minerRewards).to.be.equal(expectedMinerRewards);
            });

            it('should execute accountFees for ZAccount activation with donation', async function () {
                await token.approve(
                    owner.address,
                    ethers.utils.parseEther('10'),
                );
                await token.transferFrom(
                    owner.address,
                    feeMaster.address,
                    ethers.utils.parseEther('10'),
                );
                await feeMaster.increaseZkpTokenDonations(
                    ethers.utils.parseEther('10'),
                );

                const initialDonationReserve =
                    await feeMaster.zkpTokenDonationReserve();

                const zAccActivationDonationAmt =
                    await feeMaster.donations(259);

                const feeData: FeeData = {
                    txType: 256, // TT_ZACCOUNT_ACTIVATION value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 1000000,
                    scChargedZkpAmount: 2500000,
                };

                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40))'
                ](feeData);

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                const allocatedZKPFee =
                    BigInt(kycFee) + BigInt(feeData.scPaymasterZkpFee * 1e12);

                expectedMinerRewards =
                    BigInt(minerRewards) +
                    (BigInt(feeData.scChargedZkpAmount * 1e12) -
                        BigInt(allocatedZKPFee));

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );

                expect(minerRewards).to.be.equal(expectedMinerRewards);

                expect(await feeMaster.zkpTokenDonationReserve()).to.be.equal(
                    initialDonationReserve.sub(zAccActivationDonationAmt),
                );
            });
        });

        describe('PRP claim', function () {
            it('should execute accountFees for PRP Claim', async function () {
                const feeData: FeeData = {
                    txType: 259, // TT_PRP_CLAIM value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 0,
                    scChargedZkpAmount: 2500000,
                };

                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40))'
                ](feeData);

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                const allocatedZKPFee = BigInt(
                    feeData.scPaymasterZkpFee * 1e12,
                );
                const expectedMinerRewards =
                    BigInt(minerRewards) +
                    BigInt(feeData.scChargedZkpAmount * 1e12) -
                    BigInt(allocatedZKPFee);

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );
                await expect(minerRewards).to.be.equal(expectedMinerRewards);
            });

            it('should execute accountFees for PRP Claim with donation', async function () {
                const initialDonationReserve =
                    await feeMaster.zkpTokenDonationReserve();

                const prpClaimDonationAmt = await feeMaster.donations(259);

                const feeData: FeeData = {
                    txType: 259, // TT_PRP_CLAIM value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 1000000,
                    scChargedZkpAmount: 2500000,
                };

                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40))'
                ](feeData);

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                const allocatedZKPFee = BigInt(
                    feeData.scPaymasterZkpFee * 1e12,
                );
                const expectedMinerRewards =
                    BigInt(minerRewards) +
                    BigInt(feeData.scChargedZkpAmount * 1e12) -
                    BigInt(allocatedZKPFee);

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );
                expect(minerRewards).to.be.equal(expectedMinerRewards);

                expect(await feeMaster.zkpTokenDonationReserve()).to.be.equal(
                    initialDonationReserve.sub(prpClaimDonationAmt),
                );
            });
        });

        describe('PRP conversion', function () {
            it('should execute accountFees for PRP conversion', async function () {
                const feeData: FeeData = {
                    txType: 260, // TT_PRP_CLAIM value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 0,
                    scChargedZkpAmount: 2500000,
                };

                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40))'
                ](feeData);

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                const allocatedZKPFee = BigInt(
                    feeData.scPaymasterZkpFee * 1e12,
                );
                const expectedMinerRewards =
                    BigInt(minerRewards) +
                    BigInt(feeData.scChargedZkpAmount * 1e12) -
                    BigInt(allocatedZKPFee);

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );
                await expect(minerRewards).to.be.equal(expectedMinerRewards);
            });

            it('should execute accountFees for PRP conversion with donation', async function () {
                const initialDonationReserve =
                    await feeMaster.zkpTokenDonationReserve();

                const prpConvertionDonationAmt = await feeMaster.donations(260);

                const feeData: FeeData = {
                    txType: 260, // TT_PRP_CLAIM value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 1000000,
                    scChargedZkpAmount: 2500000,
                };

                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40))'
                ](feeData);

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                const allocatedZKPFee = BigInt(
                    feeData.scPaymasterZkpFee * 1e12,
                );
                const expectedMinerRewards =
                    BigInt(minerRewards) +
                    BigInt(feeData.scChargedZkpAmount * 1e12) -
                    BigInt(allocatedZKPFee);

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );
                expect(minerRewards).to.be.equal(expectedMinerRewards);

                expect(await feeMaster.zkpTokenDonationReserve()).to.be.equal(
                    initialDonationReserve.sub(prpConvertionDonationAmt),
                );
            });
        });

        describe('ZSwap', function () {
            it('should execute accountFees for ZSwap', async function () {
                const feeData: FeeData = {
                    txType: 262, // TT_ZSWAP value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: ethers.BigNumber.from('100000'),
                    scAddedZkpAmount: 0,
                    scChargedZkpAmount: 2500000,
                };

                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40))'
                ](feeData);

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                const allocatedZKPFee = BigInt(
                    feeData.scPaymasterZkpFee * 1e12,
                );
                const expectedMinerRewards =
                    BigInt(minerRewards) +
                    BigInt(feeData.scChargedZkpAmount * 1e12) -
                    BigInt(allocatedZKPFee);

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );
                await expect(minerRewards).to.be.equal(expectedMinerRewards);
            });

            it('should execute accountFees for ZSwap with donation', async function () {
                const initialDonationReserve =
                    await feeMaster.zkpTokenDonationReserve();

                const zSwapDonationAmt = await feeMaster.donations(262);

                const feeData: FeeData = {
                    txType: 262, // TT_ZSWAP value
                    numOutputUtxos: 2,
                    scPaymasterZkpFee: 100000,
                    scAddedZkpAmount: 1000000,
                    scChargedZkpAmount: 2500000,
                };

                await feeMaster[
                    'accountFees((uint16,uint8,uint40,uint40,uint40))'
                ](feeData);

                expect(
                    await feeMaster.debts(payMaster.address, token.address),
                ).to.be.equal(0);

                const allocatedZKPFee = BigInt(
                    feeData.scPaymasterZkpFee * 1e12,
                );
                const expectedMinerRewards =
                    BigInt(minerRewards) +
                    BigInt(feeData.scChargedZkpAmount * 1e12) -
                    BigInt(allocatedZKPFee);

                minerRewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );
                await expect(minerRewards).to.be.equal(expectedMinerRewards);

                expect(await feeMaster.zkpTokenDonationReserve()).to.be.equal(
                    initialDonationReserve.sub(zSwapDonationAmt),
                );
            });
        });

        describe('PayOff', function () {
            it('should execute payoff function to distribute miner rewards', async function () {
                expect(
                    await token.balanceOf(pantherBusTree.address),
                ).to.be.equal(0);
                const rewards = await feeMaster.debts(
                    pantherBusTree.address,
                    token.address,
                );
                await feeMaster
                    .connect(pantherBusTree)
                    ['payOff(address,address)'](
                        token.address,
                        pantherBusTree.address,
                    );

                expect(
                    await token.balanceOf(pantherBusTree.address),
                ).to.be.equal(rewards);
                expect(
                    await feeMaster.debts(
                        pantherBusTree.address,
                        token.address,
                    ),
                ).to.be.equal(0);
            });

            it('should execute payoff function to distribute protocolfee', async function () {
                const protocolFee = await feeMaster.debts(
                    pantherPoolV1.address,
                    token.address,
                );
                const signer = await impersonate(pantherPoolV1.address);
                await ensureMinBalance(
                    pantherPoolV1.address,
                    ethers.utils.parseEther('10'),
                );
                expect(
                    await token.balanceOf(pantherPoolV1.address),
                ).to.be.equal(0);

                await feeMaster
                    .connect(signer)
                    ['payOff(address,address)'](
                        token.address,
                        pantherPoolV1.address,
                    );
                expect(
                    await token.balanceOf(pantherPoolV1.address),
                ).to.be.equal(protocolFee);
                expect(
                    await feeMaster.debts(pantherPoolV1.address, token.address),
                ).to.be.equal(0);
            });

            it('should execute payoff function to distribute native token rewards', async function () {
                const initialBal = await ethers.provider.getBalance(
                    payMaster.address,
                );

                const rewards = await feeMaster.debts(
                    payMaster.address,
                    ethers.constants.AddressZero,
                );

                await feeMaster
                    .connect(payMaster)
                    ['payOff(address)'](payMaster.address);

                expect(
                    await ethers.provider.getBalance(payMaster.address),
                ).to.be.greaterThan(initialBal);

                expect(
                    await ethers.provider.getBalance(payMaster.address),
                ).to.be.lessThanOrEqual(initialBal.add(rewards));

                expect(
                    await feeMaster.debts(
                        payMaster.address,
                        ethers.constants.AddressZero,
                    ),
                ).to.be.equal(0);
            });

            it('should revert if the debt is zero', async function () {
                await expect(
                    feeMaster
                        .connect(payMaster)
                        ['payOff(address)'](payMaster.address),
                ).to.be.revertedWith('zero debt');

                await expect(
                    feeMaster
                        .connect(pantherBusTree)
                        ['payOff(address,address)'](
                            token.address,
                            pantherBusTree.address,
                        ),
                ).to.be.revertedWith('zero debt');
            });
        });
    });

    type FeeData = {
        txType: number;
        numOutputUtxos: number;
        scPaymasterZkpFee: number;
        scAddedZkpAmount: number;
        scChargedZkpAmount: number;
    };

    type AssetData = {
        tokenAddress: string;
        depositAmount: number;
        withdrawAmount: number;
    };

    type providersStruct = {
        pantherPool: string;
        pantherBusTree: string;
        paymaster: string;
        trustProvider: string;
    };
});
