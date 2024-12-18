// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {smock, FakeContract} from '@defi-wonderland/smock';
import {BigNumberish} from '@ethersproject/bignumber/lib/bignumber';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers, network} from 'hardhat';

import {revertSnapshot, takeSnapshot} from '../../lib/hardhat';
import {
    IUniswapV3Pool,
    MockPantherPoolV1,
    MockFeeMaster,
    TokenMock,
    WETH9,
} from '../../types/contracts';

import {randomInputGenerator} from './helpers/randomSnarkFriendlyInputGenerator';

describe('FeeMaster Contract', function () {
    let feeMaster: MockFeeMaster;
    let weth: WETH9;
    let zkp: TokenMock;
    let usdt: TokenMock;
    let uniswapV3Pool: FakeContract<IUniswapV3Pool>;
    let pantherPoolV1: FakeContract<MockPantherPoolV1>;

    let owner: SignerWithAddress;
    let user: SignerWithAddress;
    let vaultV1: SignerWithAddress;
    let treasury: SignerWithAddress;
    let pantherTrees: SignerWithAddress;
    let paymaster: SignerWithAddress;
    let trustProvider: SignerWithAddress;

    let snapshotId: number;

    const ZERO_ADDRESS = ethers.constants.AddressZero;
    const NATIVE_ADDRESS = ZERO_ADDRESS;

    const SCALE = 1e12;

    enum TxType {
        ZACCOUNT_ACTIVATION = 0x100,
        PRP_ACCOUNTING = 0x103,
        PRP_CONVERSION = 0x104,
        MAIN_TRANSACTION = 0x105,
        ZSWAP = 0x106,
    }

    before(async () => {
        [
            ,
            owner,
            user,
            pantherTrees,
            vaultV1,
            treasury,
            paymaster,
            trustProvider,
        ] = await ethers.getSigners();

        weth = await (await ethers.getContractFactory('WETH9')).deploy();
        zkp = await (
            await ethers.getContractFactory('TokenMock', owner)
        ).deploy();
        usdt = await (
            await ethers.getContractFactory('TokenMock', owner)
        ).deploy();

        uniswapV3Pool = await smock.fake('IUniswapV3Pool');
    });

    beforeEach(async function () {
        snapshotId = await takeSnapshot();

        // creating a new pantherPoolV1 fake to keep track of how many times its methods have
        // been executed on each specific unit test
        pantherPoolV1 = await smock.fake('MockPantherPoolV1');

        // Prepare Providers struct
        const Providers = {
            pantherPool: pantherPoolV1.address,
            pantherTrees: pantherTrees.address,
            paymaster: paymaster.address,
            trustProvider: trustProvider.address,
        };

        // Deploy FeeMaster
        const FeeMasterFactoryArtifact =
            await ethers.getContractFactory('MockFeeMaster');

        feeMaster = await FeeMasterFactoryArtifact.connect(owner).deploy(
            await owner.getAddress(),
            Providers,
            zkp.address,
            weth.address,
            vaultV1.address,
            treasury.address,
        );

        await feeMaster.deployed();
    });

    afterEach(async () => {
        await revertSnapshot(snapshotId);
    });

    describe('#updateFeeParams', () => {
        const newPerUtxoReward = ethers.utils.parseEther('100'); // 1e12
        const newPerKytFee = ethers.utils.parseEther('200'); // 2e12
        const newKycFee = ethers.utils.parseEther('300'); // 3e12
        const newProtocolFeePercentage = 2000; // 20%

        it('should update the fee params by owner', async () => {
            await expect(
                feeMaster
                    .connect(owner)
                    .updateFeeParams(
                        newPerUtxoReward,
                        newPerKytFee,
                        newKycFee,
                        newProtocolFeePercentage,
                    ),
            )
                .to.emit(feeMaster, 'FeeParamsUpdated')
                .withArgs([
                    newPerUtxoReward.div(SCALE),
                    newPerKytFee.div(SCALE),
                    newKycFee.div(SCALE),
                    2000,
                ]);

            const feeParams = await feeMaster.feeParams();

            expect(feeParams.scPerUtxoReward).to.equal(
                newPerUtxoReward.div(SCALE),
            );
            expect(feeParams.scPerKytFee).to.equal(newPerKytFee.div(SCALE));
            expect(feeParams.scKycFee).to.equal(newKycFee.div(SCALE));
            expect(feeParams.protocolFeePercentage).to.equal(
                newProtocolFeePercentage,
            );
        });

        it('should revert when executed by non-owner', async () => {
            await expect(
                feeMaster
                    .connect(user)
                    .updateFeeParams(
                        newPerUtxoReward,
                        newPerKytFee,
                        newKycFee,
                        newProtocolFeePercentage,
                    ),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('#updateProtocolZkpFeeDistributionParams', () => {
        const newTreasuryLockPercentage = 1500; // 15%
        const newMinRewardableZkpAmount = ethers.BigNumber.from('500');

        it('should update the protocol ZKP fee distribution params by owner', async () => {
            await expect(
                feeMaster
                    .connect(owner)
                    .updateProtocolZkpFeeDistributionParams(
                        newTreasuryLockPercentage,
                        newMinRewardableZkpAmount,
                    ),
            )
                .to.emit(feeMaster, 'ProtocolZkpFeeDistributionParamsUpdated')
                .withArgs(newTreasuryLockPercentage, newMinRewardableZkpAmount);
        });

        it('should revert when executed by non-owner', async () => {
            await expect(
                feeMaster
                    .connect(user)
                    .updateProtocolZkpFeeDistributionParams(
                        newTreasuryLockPercentage,
                        newMinRewardableZkpAmount,
                    ),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('#updateDonations', () => {
        const txTypes = [1, 2, 3];
        const donateAmounts = [
            ethers.BigNumber.from('1000'),
            ethers.BigNumber.from('2000'),
            ethers.BigNumber.from('3000'),
        ];

        it('should update donations by owner and emit DonationsUpdated events', async () => {
            for (let i = 0; i < txTypes.length; i++) {
                await expect(
                    feeMaster
                        .connect(owner)
                        .updateDonations([txTypes[i]], [donateAmounts[i]]),
                )
                    .to.emit(feeMaster, 'DonationsUpdated')
                    .withArgs(txTypes[i], donateAmounts[i]);
            }

            for (let i = 0; i < txTypes.length; i++) {
                const donation = await feeMaster.donations(txTypes[i]);
                expect(donation).to.equal(donateAmounts[i]);
            }
        });

        it('should revert when executed by non-owner', async () => {
            await expect(
                feeMaster.connect(user).updateDonations(txTypes, donateAmounts),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should revert if txTypes and donateAmounts length mismatch', async () => {
            await expect(
                feeMaster.connect(owner).updateDonations([1, 2], [1000]),
            ).to.be.revertedWith('mismatch length');
        });
    });

    describe('#updateNativeTokenReserveTarget', () => {
        const newReserveTarget = ethers.utils.parseEther('1000'); // 1000 ETH

        it('should update the native token reserve target by owner and emit NativeTokenReserveTargetUpdated event', async () => {
            await expect(
                feeMaster
                    .connect(owner)
                    .updateNativeTokenReserveTarget(newReserveTarget),
            )
                .to.emit(feeMaster, 'NativeTokenReserveTargetUpdated')
                .withArgs(newReserveTarget);

            const reserveTarget = await feeMaster.nativeTokenReserveTarget();
            expect(reserveTarget).to.equal(newReserveTarget);
        });

        it('should revert when executed by non-owner', async () => {
            await expect(
                feeMaster
                    .connect(user)
                    .updateNativeTokenReserveTarget(newReserveTarget),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('#increaseNativeTokenReserves', () => {
        const depositAmount = ethers.utils.parseEther('10'); // 10 ETH

        it('should increase native token reserves by owner', async () => {
            await expect(
                feeMaster
                    .connect(owner)
                    .increaseNativeTokenReserves({value: depositAmount}),
            )
                .to.emit(feeMaster, 'NativeTokenReserveUpdated')
                .withArgs(depositAmount);

            const reserve = await feeMaster.nativeTokenReserve();
            expect(reserve).to.equal(depositAmount);

            // Verify that adjustVaultAssetsAndUpdateTotalFeeMasterDebt was called with correct parameters
            expect(
                pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
            ).to.have.been.calledWith(
                ZERO_ADDRESS,
                depositAmount,
                feeMaster.address,
            );
        });

        it('should revert when executed by non-owner', async () => {
            await expect(
                feeMaster
                    .connect(user)
                    .increaseNativeTokenReserves({value: depositAmount}),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should revert when deposit amount is zero', async () => {
            await expect(
                feeMaster
                    .connect(owner)
                    .increaseNativeTokenReserves({value: 0}),
            ).to.be.revertedWith('invalid amount');
        });
    });

    describe('#increaseZkpTokenDonations', () => {
        const donationAmount = ethers.BigNumber.from('5000');

        it('should increase ZKP token donations by owner', async () => {
            await expect(
                feeMaster
                    .connect(owner)
                    .increaseZkpTokenDonations(donationAmount),
            )
                .to.emit(feeMaster, 'ZkpTokenDonationsUpdated')
                .withArgs(donationAmount);

            const donationReserve = await feeMaster.zkpTokenDonationReserve();
            expect(donationReserve).to.equal(donationAmount);

            // Verify that adjustVaultAssetsAndUpdateTotalFeeMasterDebt was called with correct parameters
            expect(
                pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
            ).to.have.been.calledWith(
                zkp.address,
                donationAmount,
                feeMaster.address,
            );
        });

        it('should revert when executed by non-owner', async () => {
            await expect(
                feeMaster
                    .connect(user)
                    .increaseZkpTokenDonations(donationAmount),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should handle multiple donations correctly', async () => {
            await feeMaster
                .connect(owner)
                .increaseZkpTokenDonations(donationAmount);

            await feeMaster
                .connect(owner)
                .increaseZkpTokenDonations(donationAmount);

            const donationReserve = await feeMaster.zkpTokenDonationReserve();
            expect(donationReserve).to.equal(donationAmount.mul(2));

            // Verify that adjustVaultAssetsAndUpdateTotalFeeMasterDebt was called twice with correct parameters
            expect(pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt)
                .to.have.been.calledTwice;
            expect(
                pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
            ).to.have.been.calledWith(
                zkp.address,
                donationAmount,
                feeMaster.address,
            );
        });
    });

    describe('#updateTwapPeriod', () => {
        const newTwapPeriod = 3600; // Example: 1 hour in seconds

        it('should update the twap period by owner and emit TwapPeriodUpdated event', async () => {
            await expect(
                feeMaster.connect(owner).updateTwapPeriod(newTwapPeriod),
            )
                .to.emit(feeMaster, 'TwapPeriodUpdated')
                .withArgs(newTwapPeriod);

            const twapPeriod = await feeMaster.twapPeriod();
            expect(twapPeriod).to.equal(newTwapPeriod);
        });

        it('should revert when executed by non-owner', async () => {
            await expect(
                feeMaster.connect(user).updateTwapPeriod(newTwapPeriod),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should revert if twapPeriod is zero', async () => {
            await expect(
                feeMaster.connect(owner).updateTwapPeriod(0),
            ).to.be.revertedWith('zero twap');
        });
    });

    describe('#updatePool', () => {
        const poolAddress = ethers.Wallet.createRandom().address;
        const tokenA = ethers.Wallet.createRandom().address;
        const tokenB = ethers.Wallet.createRandom().address;
        const status = true;

        it('should add a new pool by owner', async () => {
            const poolKey = getPoolKey(tokenA, tokenB);

            await expect(
                feeMaster
                    .connect(owner)
                    .updatePool(poolAddress, tokenA, tokenB, status),
            )
                .to.emit(feeMaster, 'PoolUpdated')
                .withArgs(poolAddress, poolKey, true);

            const pool = await feeMaster.pools(poolKey);
            expect(pool._address).to.equal(poolAddress);
            expect(pool._enabled).to.equal(true);
        });

        it('should update the existing pool by owner', async () => {
            const newStatus = false;
            const poolKey = getPoolKey(tokenA, tokenB);

            await feeMaster
                .connect(owner)
                .updatePool(poolAddress, tokenA, tokenB, status);

            await expect(
                feeMaster
                    .connect(owner)
                    .updatePool(poolAddress, tokenA, tokenB, newStatus),
            )
                .to.emit(feeMaster, 'PoolUpdated')
                .withArgs(poolAddress, poolKey, newStatus);

            const pool = await feeMaster.pools(poolKey);
            expect(pool._address).to.equal(poolAddress);
            expect(pool._enabled).to.equal(newStatus);
        });

        it('should revert when executed by non-owner', async () => {
            await expect(
                feeMaster
                    .connect(user)
                    .updatePool(poolAddress, tokenA, tokenB, status),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should revert when pool address is zero', async () => {
            await expect(
                feeMaster
                    .connect(owner)
                    .updatePool(ZERO_ADDRESS, tokenA, tokenB, status),
            ).to.be.revertedWith('addPool: zero address');
        });
    });

    describe('#approveVaultToTransferZkp', () => {
        it('should approve vault to transfer ZKP tokens', async () => {
            await expect(feeMaster.approveVaultToTransferZkp())
                .to.emit(zkp, 'Approval')
                .withArgs(
                    feeMaster.address,
                    vaultV1.address,
                    ethers.constants.MaxUint256,
                );

            const allowance = await zkp.allowance(
                feeMaster.address,
                vaultV1.address,
            );
            expect(allowance).to.equal(ethers.constants.MaxUint256);
        });

        it('should overwrite existing allowance', async () => {
            // First approval
            await feeMaster.approveVaultToTransferZkp();

            // Change ZKP token address (simulate different token)
            await feeMaster.approveVaultToTransferZkp();

            const allowance = await zkp.allowance(
                feeMaster.address,
                vaultV1.address,
            );
            expect(allowance).to.equal(ethers.constants.MaxUint256);
        });
    });

    describe('#cacheNativeToZkpRate', () => {
        // Define the Time-Weighted Average Price (TWAP) period in seconds
        const twapPeriod = 60; // 60 seconds

        // The expected quote amount after caching the rate
        // Since averageTick = 0, the quoteAmount should equal the nativeAmount
        const expectedQuoteAmount = ethers.utils.parseEther('1'); // 1 ETH

        beforeEach(async () => {
            await feeMaster.connect(owner).updateTwapPeriod(twapPeriod);

            await feeMaster
                .connect(owner)
                .updatePool(
                    uniswapV3Pool.address,
                    ZERO_ADDRESS,
                    zkp.address,
                    true,
                );
        });

        it('should cache the native to ZKP rate correctly when Uniswap returns expected rate', async () => {
            await mockUniswapPoolTokens(
                uniswapV3Pool,
                zkp.address,
                weth.address,
            );

            // Mock the observe function of the Uniswap V3 pool to return predefined tick cumulatives and seconds agos
            // This simulates the response from Uniswap's oracle
            await mockUniswapPoolRate(uniswapV3Pool, 1, twapPeriod); // rate = 1:1

            // Call the function to cache the native to ZKP rate
            await feeMaster.cacheNativeToZkpRate();

            // Retrieve the cached rate from the FeeMaster contract
            const cachedRate = await feeMaster.cachedNativeRateInZkp();

            // Assert that the cached rate matches the expected quote amount
            expect(cachedRate).to.equal(expectedQuoteAmount);
        });
    });

    describe('distributeProtocolZkpFees', () => {
        const totalZkpAmount = ethers.utils.parseEther('1000');
        const treasuryPercentage = 4000;
        const minRewardableZkpAmount = ethers.utils.parseEther('1');
        const sercretHash = randomInputGenerator();
        const zkpDisributeVoucherType = '0xd48cb9c0';

        beforeEach(async () => {
            await feeMaster
                .connect(owner)
                .updateProtocolZkpFeeDistributionParams(
                    treasuryPercentage,
                    minRewardableZkpAmount,
                );

            await feeMaster.internalUpdateDebtForProtocol(
                zkp.address,
                totalZkpAmount,
            );
        });

        it('should distribute the tokens and generate rewards', async () => {
            // Mock PantherPoolV1 adjustVaultAssetsAndUpdateTotalFeeMasterDebt
            pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt.returns();

            // assuming zkp tokens have been received from Vault
            await zkp
                .connect(owner)
                .transfer(feeMaster.address, totalZkpAmount);

            await expect(feeMaster.distributeProtocolZkpFees(sercretHash))
                .to.emit(feeMaster, 'ZkpsDistributed')
                .withArgs(totalZkpAmount);

            // Verify debts for trustProvider and pantherTrees
            expect(
                await feeMaster.debts(pantherPoolV1.address, zkp.address),
            ).to.equal(0);

            expect(await zkp.balanceOf(treasury.address)).to.be.eq(
                ethers.utils.parseEther('400'),
            );
            expect(await zkp.balanceOf(pantherPoolV1.address)).to.be.eq(
                ethers.utils.parseEther('600'),
            );

            // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for zkpToken
            expect(
                pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
            ).to.have.been.calledWith(
                zkp.address,
                `-${totalZkpAmount.toString()}`,
                feeMaster.address,
            );

            // Verify prp rewards are generated
            expect(pantherPoolV1.generateRewards).to.have.been.calledWith(
                sercretHash,
                0,
                zkpDisributeVoucherType,
            );
        });
    });

    describe('#_tryInternalZkpToNativeConversion and _accountDebtForPaymaster', () => {
        // Define the Time-Weighted Average Price (TWAP) period in seconds
        const twapPeriod = 60; // 60 seconds

        beforeEach(async () => {
            await feeMaster.connect(owner).updateTwapPeriod(twapPeriod);

            await feeMaster
                .connect(owner)
                .updatePool(
                    uniswapV3Pool.address,
                    ZERO_ADDRESS,
                    zkp.address,
                    true,
                );

            await mockUniswapPoolTokens(
                uniswapV3Pool,
                zkp.address,
                weth.address,
            );
        });
        async function setUniswapRate(rate: number) {
            await mockUniswapPoolRate(uniswapV3Pool, rate, twapPeriod);
        }
        /**
         * Helper function to set the Uniswap pool's rate.
         * @param rate The desired rate of ZKP to Native (e.g., 1 for 1:1).
         */

        it('should proccess paymaster debt in ZKP when neither native reserve nor protocol debt is available', async function () {
            const paymasterCompensationInZkp = ethers.utils.parseEther('1000');
            const expectedPaymasterDebtInNative = 0;

            // Ensure native reserves and protocol debts are zero
            expect(await feeMaster.nativeTokenReserve()).to.equal(0);
            expect(
                await feeMaster.debts(pantherPoolV1.address, NATIVE_ADDRESS),
            ).to.equal(0);

            // Mock Uniswap rate to 1:1
            await setUniswapRate(1);

            // Call the internal conversion function
            await expect(
                feeMaster
                    .connect(user)
                    .internalTryInternalZkpToNativeConversion(
                        paymasterCompensationInZkp,
                    ),
            )
                .to.emit(feeMaster, 'PaymasterCompensationConverted')
                .withArgs(
                    paymasterCompensationInZkp,
                    expectedPaymasterDebtInNative,
                );
        });

        it('should proccess paymaster debt in native when native reserve is sufficient', async function () {
            const paymasterCompensationInZkp = ethers.utils.parseEther('1000');
            const nativeReserveBefore = ethers.utils.parseEther('10'); // 10 ETH

            const expectedPaymasterDebtInNative = nativeReserveBefore;
            const expectedPaymasterDebtInZkp =
                paymasterCompensationInZkp.sub(nativeReserveBefore);

            // Increase native reserves
            await feeMaster
                .connect(owner)
                .increaseNativeTokenReserves({value: nativeReserveBefore});

            // Mock Uniswap rate to 1:1
            await setUniswapRate(1);

            // Call the internal conversion function
            await expect(
                feeMaster
                    .connect(user)
                    .internalTryInternalZkpToNativeConversion(
                        paymasterCompensationInZkp,
                    ),
            )
                .to.emit(feeMaster, 'PaymasterCompensationConverted')
                .withArgs(
                    expectedPaymasterDebtInZkp,
                    expectedPaymasterDebtInNative,
                );

            const nativeReserveAfter = await feeMaster.nativeTokenReserve();
            expect(nativeReserveAfter).to.equal(0);
        });

        it('should proccess paymaster debt in native when native reserve is insufficient but protocol debts is sufficient', async function () {
            const paymasterCompensationInZkp = ethers.utils.parseEther('1000');
            const protocolDebtBefore = ethers.utils.parseEther('2000'); // 2000 ETH
            const nativeReserveBefore = ethers.utils.parseEther('1'); // 3 ETH

            const expectedPaymasterDebtInZkp = 0;
            const expectedPaymasterDebtInNative = paymasterCompensationInZkp;

            // Increase native reserves
            await feeMaster
                .connect(owner)
                .increaseNativeTokenReserves({value: nativeReserveBefore});

            // Mock protocol debt by updating debts
            await feeMaster
                .connect(owner)
                .internalUpdateDebtForProtocol(
                    NATIVE_ADDRESS,
                    protocolDebtBefore,
                );

            // Mock Uniswap rate to 1:1
            await setUniswapRate(1);

            // Call the internal conversion function
            await expect(
                feeMaster
                    .connect(user)
                    .internalTryInternalZkpToNativeConversion(
                        paymasterCompensationInZkp,
                    ),
            )
                .to.emit(feeMaster, 'PaymasterCompensationConverted')
                .withArgs(
                    expectedPaymasterDebtInZkp,
                    expectedPaymasterDebtInNative,
                );

            // Verify that nativeTokenReserve is now 0
            expect(await feeMaster.nativeTokenReserve()).to.equal(0);
        });

        it('should proccess paymaster debt in both native and zkp when native reserve is insufficient and protocol debts is not enough', async function () {
            const paymasterCompensationInZkp = ethers.utils.parseEther('1000');
            const protocolDebtBefore = ethers.utils.parseEther('300'); // 300 ETH

            const expectedPaymasterDebtInZkp = ethers.utils.parseEther('700');
            const expectedPaymasterDebtInNative = protocolDebtBefore;

            // Ensure native reserves are zero
            expect(await feeMaster.nativeTokenReserve()).to.equal(0);

            // Mock protocol debt by updating debts
            await feeMaster
                .connect(owner)
                .internalUpdateDebtForProtocol(
                    NATIVE_ADDRESS,
                    protocolDebtBefore,
                );

            // Mock Uniswap rate to 1:1
            await setUniswapRate(1);

            // Call the internal conversion function
            await expect(
                feeMaster
                    .connect(user)
                    .internalTryInternalZkpToNativeConversion(
                        paymasterCompensationInZkp,
                    ),
            )
                .to.emit(feeMaster, 'PaymasterCompensationConverted')
                .withArgs(
                    expectedPaymasterDebtInZkp,
                    expectedPaymasterDebtInNative,
                );
        });

        it('should account paymaster debt in both native and zkp when native reserve is insufficient and protocol debts is not enough', async function () {
            const paymasterCompensationInZkp = ethers.utils.parseEther('1000');
            const protocolDebtBefore = ethers.utils.parseEther('300'); // 300 ETH

            const expectedPaymasterDebtInZkp = ethers.utils.parseEther('700');
            const expectedPaymasterDebtInNative = protocolDebtBefore;

            // Ensure native reserves are zero
            expect(await feeMaster.nativeTokenReserve()).to.equal(0);

            // Mock protocol debt by updating debts
            await feeMaster
                .connect(owner)
                .internalUpdateDebtForProtocol(
                    NATIVE_ADDRESS,
                    protocolDebtBefore,
                );

            // Mock Uniswap rate to 1:1
            await setUniswapRate(1);

            // Call the internal conversion function
            await expect(
                feeMaster
                    .connect(user)
                    .internalAccountDebtForPaymaster(
                        paymasterCompensationInZkp,
                    ),
            )
                .to.emit(feeMaster, 'PaymasterCompensationConverted')
                .withArgs(
                    expectedPaymasterDebtInZkp,
                    expectedPaymasterDebtInNative,
                )
                .and.to.emit(feeMaster, 'DebtsUpdated')
                .withArgs(
                    paymaster.address,
                    zkp.address,
                    expectedPaymasterDebtInZkp,
                )
                .and.to.emit(feeMaster, 'DebtsUpdated')
                .withArgs(
                    paymaster.address,
                    NATIVE_ADDRESS,
                    expectedPaymasterDebtInNative,
                );

            expect(
                await feeMaster.debts(paymaster.address, zkp.address),
            ).to.equal(expectedPaymasterDebtInZkp);

            expect(
                await feeMaster.debts(paymaster.address, NATIVE_ADDRESS),
            ).to.equal(expectedPaymasterDebtInNative);
        });
    });

    describe('#accountFees', () => {
        const twapPeriod = 60; // 60 seconds
        const perUtxoReward = ethers.utils.parseEther('5');
        const perKytFee = ethers.utils.parseEther('1');
        const kycFee = ethers.utils.parseEther('3');
        const protocolFeePercentage = 2000;

        let pantherPoolAsSigner: SignerWithAddress;

        function createFeeData(
            txType: TxType,
            numOutputUtxos: number,
            paymasterZkpFee: BigNumberish,
            addedZkpAmount: BigNumberish,
            chargedZkpAmount: BigNumberish,
        ) {
            return {
                txType,
                numOutputUtxos,
                scPaymasterZkpFee: BigNumber.from(paymasterZkpFee).div(SCALE),
                scAddedZkpAmount: BigNumber.from(addedZkpAmount).div(SCALE),
                scChargedZkpAmount: BigNumber.from(chargedZkpAmount).div(SCALE),
            };
        }

        beforeEach(async () => {
            await feeMaster.connect(owner).updateTwapPeriod(twapPeriod);
            await mockUniswapPoolRate(uniswapV3Pool, 1, twapPeriod);

            await feeMaster
                .connect(owner)
                .updateFeeParams(
                    perUtxoReward,
                    perKytFee,
                    kycFee,
                    protocolFeePercentage,
                );

            await feeMaster
                .connect(owner)
                .updatePool(
                    uniswapV3Pool.address,
                    ZERO_ADDRESS,
                    zkp.address,
                    true,
                );

            // Impersonate pantherPoolV1.address
            await network.provider.request({
                method: 'hardhat_impersonateAccount',
                params: [pantherPoolV1.address],
            });
            pantherPoolAsSigner = await ethers.getSigner(pantherPoolV1.address);

            await owner.sendTransaction({
                to: pantherPoolAsSigner.address,
                value: ethers.utils.parseEther('10'),
            });

            await mockUniswapPoolTokens(
                uniswapV3Pool,
                zkp.address,
                weth.address,
            );
        });

        describe('zAccount activation tx', () => {
            const utxos = 2;
            const miningRewards = perUtxoReward.mul(utxos);
            const chargedAmount = miningRewards.add(kycFee);

            it('should process fees without donation for direct tx', async () => {
                const feeData = createFeeData(
                    TxType.ZACCOUNT_ACTIVATION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(trustProvider.address, zkp.address, kycFee)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                // Verify debts for trustProvider and pantherTrees
                expect(
                    await feeMaster.debts(trustProvider.address, zkp.address),
                ).to.equal(kycFee);
                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
            });

            it('should process fees with available donation for direct tx', async () => {
                // Set total available donations
                const totalDonationAmount = ethers.utils.parseEther('1000000'); // 1m zkps
                await feeMaster
                    .connect(owner)
                    .increaseZkpTokenDonations(totalDonationAmount);

                // Set donation for ZACCOUNT_ACTIVATION tx type
                await feeMaster
                    .connect(owner)
                    .updateDonations(
                        [TxType.ZACCOUNT_ACTIVATION],
                        [chargedAmount],
                    );

                const feeData = createFeeData(
                    TxType.ZACCOUNT_ACTIVATION,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(trustProvider.address, zkp.address, kycFee)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                // Verify debts for trustProvider and pantherTrees
                expect(
                    await feeMaster.debts(trustProvider.address, zkp.address),
                ).to.equal(kycFee);
                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);

                // Verify donation reserve is decreased
                expect(await feeMaster.zkpTokenDonationReserve()).to.equal(
                    totalDonationAmount.sub(chargedAmount),
                );
            });

            it('should process fees without donation for tx that comes from bundlers', async () => {
                const nativeReserve = ethers.utils.parseEther('5'); // 5 ETH
                // Increase native reserves
                await feeMaster
                    .connect(owner)
                    .increaseNativeTokenReserves({value: nativeReserve});

                const paymasterZkpCompensation = ethers.utils.parseEther('1'); // 1 zkp
                const chargedAmountWithPaymasterCompensation =
                    chargedAmount.add(paymasterZkpCompensation);
                const feeData = createFeeData(
                    TxType.ZACCOUNT_ACTIVATION,
                    utxos,
                    paymasterZkpCompensation, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmountWithPaymasterCompensation, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(trustProvider.address, zkp.address, kycFee)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(
                        paymaster.address,
                        NATIVE_ADDRESS,
                        paymasterZkpCompensation, // mocking 1:1 ration between zkp and native via `mockUniswapPoolRate`
                    );

                expect(
                    await feeMaster.debts(trustProvider.address, zkp.address),
                ).to.equal(kycFee);
                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
                expect(
                    await feeMaster.debts(paymaster.address, NATIVE_ADDRESS),
                ).to.equal(paymasterZkpCompensation);
            });

            it('should revert when user requests donation but it is unavailable', async () => {
                const feeData = createFeeData(
                    TxType.ZACCOUNT_ACTIVATION,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                ).to.be.revertedWith('invalid donation amount');
            });

            it('should revert with "insufficient mining rewards" when mining fee is inadequate', async () => {
                const feeData = createFeeData(
                    TxType.ZACCOUNT_ACTIVATION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    kycFee, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                ).to.be.revertedWith('insufficient mining rewards');
            });
        });

        describe('prp acounting tx', () => {
            const utxos = 1;
            const chargedAmount = perUtxoReward.mul(utxos);

            // this tx contains has 1 utxos
            // check `_accountPrpConversionOrClaimFees` in the contract
            it('should process fees without donation for direct tx', async () => {
                const feeData = createFeeData(
                    TxType.PRP_ACCOUNTING,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, perUtxoReward);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(perUtxoReward);
            });

            it('should process fees with available donation for direct tx', async () => {
                // Set total available donations
                const totalDonationAmount = ethers.utils.parseEther('1000000'); // 1m zkps
                await feeMaster
                    .connect(owner)
                    .increaseZkpTokenDonations(totalDonationAmount);

                // Set donation for PRP_ACCOUNTING tx type
                await feeMaster
                    .connect(owner)
                    .updateDonations([TxType.PRP_ACCOUNTING], [chargedAmount]);

                const feeData = createFeeData(
                    TxType.PRP_ACCOUNTING,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, perUtxoReward);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(perUtxoReward);

                // Verify donation reserve is decreased
                expect(await feeMaster.zkpTokenDonationReserve()).to.equal(
                    totalDonationAmount.sub(chargedAmount),
                );
            });

            it('should process fees without donation for tx that comes from bundlers', async () => {
                const nativeReserve = ethers.utils.parseEther('5'); // 5 ETH
                // Increase native reserves
                await feeMaster
                    .connect(owner)
                    .increaseNativeTokenReserves({value: nativeReserve});

                const paymasterZkpCompensation = ethers.utils.parseEther('1'); // 1 zkp

                const chargedAmountWithPaymasterCompensation =
                    chargedAmount.add(paymasterZkpCompensation);

                const feeData = createFeeData(
                    TxType.PRP_ACCOUNTING,
                    utxos,
                    paymasterZkpCompensation, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmountWithPaymasterCompensation, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, perUtxoReward)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(
                        paymaster.address,
                        NATIVE_ADDRESS,
                        paymasterZkpCompensation, // mocking 1:1 ration between zkp and native via `mockUniswapPoolRate`
                    );

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(perUtxoReward);
                expect(
                    await feeMaster.debts(paymaster.address, NATIVE_ADDRESS),
                ).to.equal(paymasterZkpCompensation);
            });

            it('should revert when user requests donation but it is unavailable', async () => {
                const feeData = createFeeData(
                    TxType.PRP_ACCOUNTING,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                ).to.be.revertedWith('invalid donation amount');
            });

            it('should revert with "insufficient mining rewards" when mining fee is inadequate', async () => {
                const feeData = createFeeData(
                    TxType.PRP_ACCOUNTING,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    kycFee, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                ).to.be.revertedWith('insufficient mining rewards');
            });
        });

        describe('prp conversion', () => {
            const utxos = 2;
            const miningRewards = perUtxoReward.mul(utxos);
            const chargedAmount = miningRewards;

            // this tx contains has 2 utxos
            // check `_accountPrpConversionOrClaimFees` in the contract
            it('should process fees without donation for direct tx', async () => {
                const feeData = createFeeData(
                    TxType.PRP_CONVERSION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
            });

            it('should process fees with available donation for direct tx', async () => {
                // Set total available donations
                const totalDonationAmount = ethers.utils.parseEther('1000000'); // 1m zkps
                await feeMaster
                    .connect(owner)
                    .increaseZkpTokenDonations(totalDonationAmount);

                // Set donation for PRP_CONVERSION tx type
                await feeMaster
                    .connect(owner)
                    .updateDonations([TxType.PRP_CONVERSION], [chargedAmount]);

                const feeData = createFeeData(
                    TxType.PRP_CONVERSION,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);

                // Verify donation reserve is decreased
                expect(await feeMaster.zkpTokenDonationReserve()).to.equal(
                    totalDonationAmount.sub(chargedAmount),
                );
            });

            it('should process fees without donation for tx that comes from bundlers', async () => {
                const nativeReserve = ethers.utils.parseEther('5'); // 5 ETH
                // Increase native reserves
                await feeMaster
                    .connect(owner)
                    .increaseNativeTokenReserves({value: nativeReserve});

                const paymasterZkpCompensation = ethers.utils.parseEther('1'); // 1 zkp

                const chargedAmountWithPaymasterCompensation =
                    chargedAmount.add(paymasterZkpCompensation);

                const feeData = createFeeData(
                    TxType.PRP_CONVERSION,
                    utxos,
                    paymasterZkpCompensation, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmountWithPaymasterCompensation, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(
                        paymaster.address,
                        NATIVE_ADDRESS,
                        paymasterZkpCompensation, // mocking 1:1 ration between zkp and native via `mockUniswapPoolRate`
                    );

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
                expect(
                    await feeMaster.debts(paymaster.address, NATIVE_ADDRESS),
                ).to.equal(paymasterZkpCompensation);
            });

            it('should revert when user requests donation but it is unavailable', async () => {
                const feeData = createFeeData(
                    TxType.PRP_CONVERSION,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                ).to.be.revertedWith('invalid donation amount');
            });

            it('should revert with "insufficient mining rewards" when mining fee is inadequate', async () => {
                const feeData = createFeeData(
                    TxType.PRP_CONVERSION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    kycFee, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                ).to.be.revertedWith('insufficient mining rewards');
            });
        });

        describe('z swap tx', () => {
            const utxos = 3;
            const miningRewards = perUtxoReward.mul(utxos);
            const chargedAmount = miningRewards;

            it('should process fees without donation for direct tx', async () => {
                const feeData = createFeeData(
                    TxType.ZSWAP,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
            });

            it('should process fees with available donation for direct tx', async () => {
                // Set total available donations
                const totalDonationAmount = ethers.utils.parseEther('1000000'); // 1m zkps
                await feeMaster
                    .connect(owner)
                    .increaseZkpTokenDonations(totalDonationAmount);

                // Set donation for ZSWAP tx type
                await feeMaster
                    .connect(owner)
                    .updateDonations([TxType.ZSWAP], [chargedAmount]);

                const feeData = createFeeData(
                    TxType.ZSWAP,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);

                // Verify donation reserve is decreased
                expect(await feeMaster.zkpTokenDonationReserve()).to.equal(
                    totalDonationAmount.sub(chargedAmount),
                );
            });

            it('should process fees without donation for tx that comes from bundlers', async () => {
                const nativeReserve = ethers.utils.parseEther('5'); // 5 ETH
                // Increase native reserves
                await feeMaster
                    .connect(owner)
                    .increaseNativeTokenReserves({value: nativeReserve});

                const paymasterZkpCompensation = ethers.utils.parseEther('1'); // 1 zkp

                const chargedAmountWithPaymasterCompensation =
                    chargedAmount.add(paymasterZkpCompensation);

                const feeData = createFeeData(
                    TxType.ZSWAP,
                    utxos,
                    paymasterZkpCompensation, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmountWithPaymasterCompensation, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(
                        paymaster.address,
                        NATIVE_ADDRESS,
                        paymasterZkpCompensation, // mocking 1:1 ration between zkp and native via `mockUniswapPoolRate`
                    );

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
                expect(
                    await feeMaster.debts(paymaster.address, NATIVE_ADDRESS),
                ).to.equal(paymasterZkpCompensation);
            });

            it('should revert when user requests donation but it is unavailable', async () => {
                const feeData = createFeeData(
                    TxType.ZSWAP,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                ).to.be.revertedWith('invalid donation amount');
            });

            it('should revert with "insufficient mining rewards" when mining fee is inadequate', async () => {
                const feeData = createFeeData(
                    TxType.ZSWAP,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    kycFee, // scChargedZkpAmount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                            feeData,
                        ),
                ).to.be.revertedWith('insufficient mining rewards');
            });
        });

        describe('main tx', () => {
            const utxos = 5;
            const miningRewards = perUtxoReward.mul(utxos);
            const chargedAmount = miningRewards;

            const chargedAmountForDeposit = chargedAmount.add(perKytFee);
            const chargedAmountForWithdraw = chargedAmount.add(perKytFee);
            const chargedAmountForDepositAndWithdraw = chargedAmount.add(
                perKytFee.mul(2),
            );

            function createAssetData(
                tokenAddress: string,
                depositAmount: BigNumberish,
                withdrawAmount: BigNumberish,
            ) {
                return {
                    tokenAddress,
                    depositAmount,
                    withdrawAmount,
                };
            }

            it('should process fees without donation for internal main tx for direct tx', async () => {
                const feeData = createFeeData(
                    TxType.MAIN_TRANSACTION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                const assetData = createAssetData(
                    usdt.address, // token address
                    0, // depsoit amount
                    0, // withdraw amount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        [
                            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                        ](feeData, assetData),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
            });

            it('should process fees without donation for deposit main tx for direct tx', async () => {
                const depositAmount = ethers.utils.parseEther('100');
                const feeData = createFeeData(
                    TxType.MAIN_TRANSACTION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmountForDeposit, // scChargedZkpAmount
                );

                const assetData = createAssetData(
                    usdt.address, // token address
                    depositAmount, // depsoit amount
                    0, // withdraw amount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        [
                            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                        ](feeData, assetData),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(trustProvider.address, zkp.address, perKytFee);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
                expect(
                    await feeMaster.debts(trustProvider.address, zkp.address),
                ).to.equal(perKytFee);
            });

            it('should process fees without donation for withdraw main tx for direct tx', async () => {
                const withdrawAmount = ethers.utils.parseEther('100');
                const protocolFee = withdrawAmount
                    .mul(protocolFeePercentage)
                    .div(10000);

                const feeData = createFeeData(
                    TxType.MAIN_TRANSACTION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmountForWithdraw, // scChargedZkpAmount
                );

                const assetData = createAssetData(
                    usdt.address, // token address
                    0, // depsoit amount
                    withdrawAmount, // withdraw amount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        [
                            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                        ](feeData, assetData),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(trustProvider.address, zkp.address, perKytFee)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherPoolV1.address, usdt.address, protocolFee);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
                expect(
                    await feeMaster.debts(trustProvider.address, zkp.address),
                ).to.equal(perKytFee);
                expect(
                    await feeMaster.debts(pantherPoolV1.address, usdt.address),
                ).to.equal(protocolFee);
            });

            it('should process fees without donation for withdraw and deposit main tx for direct tx', async () => {
                const depsoitAmount = ethers.utils.parseEther('50');
                const withdrawAmount = ethers.utils.parseEther('100');
                const protocolFee = withdrawAmount
                    .mul(protocolFeePercentage)
                    .div(10000);

                const feeData = createFeeData(
                    TxType.MAIN_TRANSACTION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmountForDepositAndWithdraw, // scChargedZkpAmount
                );

                const assetData = createAssetData(
                    usdt.address, // token address
                    depsoitAmount, // depsoit amount
                    withdrawAmount, // withdraw amount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        [
                            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                        ](feeData, assetData),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards)
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(
                        trustProvider.address,
                        zkp.address,
                        perKytFee.mul(2),
                    )
                    .and.to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherPoolV1.address, usdt.address, protocolFee);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
                expect(
                    await feeMaster.debts(trustProvider.address, zkp.address),
                ).to.equal(perKytFee.mul(2));
                expect(
                    await feeMaster.debts(pantherPoolV1.address, usdt.address),
                ).to.equal(protocolFee);
            });

            it('should process fees with available donation for direct tx', async () => {
                // Set total available donations
                const totalDonationAmount = ethers.utils.parseEther('1000000'); // 1m zkps
                await feeMaster
                    .connect(owner)
                    .increaseZkpTokenDonations(totalDonationAmount);

                // Set donation for MAIN tx type
                await feeMaster
                    .connect(owner)
                    .updateDonations(
                        [TxType.MAIN_TRANSACTION],
                        [chargedAmount],
                    );

                const feeData = createFeeData(
                    TxType.MAIN_TRANSACTION,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                const assetData = createAssetData(
                    usdt.address, // token address
                    0, // depsoit amount
                    0, // withdraw amount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        [
                            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                        ](feeData, assetData),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);

                // Verify donation reserve is decreased
                expect(await feeMaster.zkpTokenDonationReserve()).to.equal(
                    totalDonationAmount.sub(chargedAmount),
                );
            });

            it('should process fees without donation for tx that comes from bundlers', async () => {
                const nativeReserve = ethers.utils.parseEther('5'); // 5 ETH
                // Increase native reserves
                await feeMaster
                    .connect(owner)
                    .increaseNativeTokenReserves({value: nativeReserve});

                const paymasterZkpCompensation = ethers.utils.parseEther('1'); // 1 zkp

                const chargedAmountWithPaymasterCompensation =
                    chargedAmount.add(paymasterZkpCompensation);

                const feeData = createFeeData(
                    TxType.MAIN_TRANSACTION,
                    utxos,
                    paymasterZkpCompensation, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    chargedAmountWithPaymasterCompensation, // scChargedZkpAmount
                );

                const assetData = createAssetData(
                    usdt.address, // token address
                    0, // depsoit amount
                    0, // withdraw amount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        [
                            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                        ](feeData, assetData),
                )
                    .to.emit(feeMaster, 'DebtsUpdated')
                    .withArgs(pantherTrees.address, zkp.address, miningRewards);

                expect(
                    await feeMaster.debts(pantherTrees.address, zkp.address),
                ).to.equal(miningRewards);
                expect(
                    await feeMaster.debts(paymaster.address, NATIVE_ADDRESS),
                ).to.equal(paymasterZkpCompensation);
            });

            it('should revert when user requests donation but it is unavailable', async () => {
                const feeData = createFeeData(
                    TxType.MAIN_TRANSACTION,
                    utxos,
                    0, // scPaymasterZkpFee
                    chargedAmount, // scAddedZkpAmount
                    chargedAmount, // scChargedZkpAmount
                );

                const assetData = createAssetData(
                    usdt.address, // token address
                    0, // depsoit amount
                    0, // withdraw amount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        [
                            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                        ](feeData, assetData),
                ).to.be.revertedWith('invalid donation amount');
            });

            it('should revert with "insufficient mining rewards" when mining fee is inadequate', async () => {
                const feeData = createFeeData(
                    TxType.MAIN_TRANSACTION,
                    utxos,
                    0, // scPaymasterZkpFee
                    0, // scAddedZkpAmount
                    kycFee, // scChargedZkpAmount
                );
                const assetData = createAssetData(
                    usdt.address, // token address
                    0, // depsoit amount
                    0, // withdraw amount
                );

                await expect(
                    feeMaster
                        .connect(pantherPoolAsSigner)
                        [
                            'accountFees((uint16,uint8,uint40,uint40,uint40),(address,uint128,uint128))'
                        ](feeData, assetData),
                ).to.be.revertedWith('insufficient mining rewards');
            });
        });

        it('should revert when called by a non-pantherPool address', async () => {
            const feeData = createFeeData(
                TxType.ZACCOUNT_ACTIVATION,
                0,
                0,
                0,
                0,
            );

            await expect(
                feeMaster
                    .connect(user)
                    ['accountFees((uint16,uint8,uint40,uint40,uint40))'](
                        feeData,
                    ),
            ).to.be.revertedWith('only panther pool');
        });
    });

    describe('#rebalanceDebt', () => {
        const secretHash = randomInputGenerator();
        const twapPeriod = 60; // 60 seconds
        let sellToken: string;

        let uniswapV3PoolUSDTNative: FakeContract<IUniswapV3Pool>;
        let uniswapV3PoolNativeZkp: FakeContract<IUniswapV3Pool>;

        beforeEach(async () => {
            sellToken = usdt.address;

            uniswapV3PoolUSDTNative =
                await smock.fake<IUniswapV3Pool>('IUniswapV3Pool');
            uniswapV3PoolNativeZkp =
                await smock.fake<IUniswapV3Pool>('IUniswapV3Pool');

            await mockUniswapPoolTokens(
                uniswapV3PoolUSDTNative,
                usdt.address,
                weth.address,
            );
            await mockUniswapPoolTokens(
                uniswapV3PoolNativeZkp,
                zkp.address,
                weth.address,
            );

            // Update FeeMaster pools
            await feeMaster
                .connect(owner)
                .updatePool(
                    uniswapV3PoolUSDTNative.address,
                    ZERO_ADDRESS,
                    usdt.address,
                    true,
                );

            await feeMaster
                .connect(owner)
                .updatePool(
                    uniswapV3PoolNativeZkp.address,
                    ZERO_ADDRESS,
                    zkp.address,
                    true,
                );

            // weth must be able to convert weth to native
            await owner.sendTransaction({
                to: weth.address,
                value: ethers.utils.parseEther('50'),
            });

            await feeMaster.connect(owner).updateTwapPeriod(twapPeriod);
            await mockUniswapPoolRate(uniswapV3PoolNativeZkp, 1, twapPeriod);

            const minRewardableZkpAmount = ethers.utils.parseEther('1');
            const treasuryLockPercentage = 100;
            await feeMaster.updateProtocolZkpFeeDistributionParams(
                treasuryLockPercentage,
                minRewardableZkpAmount,
            );
            await feeMaster.cacheNativeToZkpRate();
        });

        function mockSwap(
            pool: FakeContract<IUniswapV3Pool>,
            sellToken: string,
            buyToken: string,
            sellAmount: BigNumberish,
            buyAmount: BigNumberish,
        ) {
            const returnArray = BigNumber.from(sellToken).lt(
                BigNumber.from(buyToken),
            )
                ? // sell token is token0 and buy token is token 1
                  [
                      BigNumber.from(sellAmount.toString()),
                      BigNumber.from(`-${buyAmount.toString()}`),
                  ]
                : // sell token is token1 and buy token is token0
                  [
                      BigNumber.from(`-${buyAmount.toString()}`),
                      BigNumber.from(sellAmount.toString()),
                  ];

            pool.swap.returns(returnArray);
        }

        describe('when native tokens are less than desired native target', () => {
            describe('when the swap does not fullfil the desired native', () => {
                it('should convert collected protocol tokens to native', async () => {
                    // increasing protocol debt collected in sell token
                    const sellTokenAmount = ethers.utils.parseEther('5');
                    await feeMaster.internalUpdateDebtForProtocol(
                        sellToken,
                        sellTokenAmount,
                    );

                    // Mock Uniswap USDT/native pool rate to 1:1
                    await mockUniswapPoolRate(
                        uniswapV3PoolUSDTNative,
                        1,
                        twapPeriod,
                    );

                    const expectedWethFromUniswap =
                        ethers.utils.parseEther('5'); // Less than target
                    await weth
                        .connect(owner)
                        .transfer(feeMaster.address, expectedWethFromUniswap);

                    const nativeTokenReserveTarget =
                        ethers.utils.parseEther('10');
                    await feeMaster
                        .connect(owner)
                        .updateNativeTokenReserveTarget(
                            nativeTokenReserveTarget,
                        );

                    const expectedZkpFromUniswap = 0;

                    // Mock PantherPoolV1 adjustVaultAssetsAndUpdateTotalFeeMasterDebt
                    pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt.returns();
                    // Mock the swap function to return (-sellTokenAmount, expectedWethFromUniswap)
                    mockSwap(
                        uniswapV3PoolUSDTNative,
                        sellToken,
                        weth.address,
                        sellTokenAmount,
                        expectedWethFromUniswap,
                    );

                    // Call rebalanceDebt
                    await expect(
                        feeMaster
                            .connect(owner)
                            .rebalanceDebt(secretHash, sellToken),
                    )
                        .to.emit(feeMaster, 'ProtocolFeeSwapped')
                        .withArgs(
                            sellToken,
                            sellTokenAmount,
                            expectedWethFromUniswap,
                            expectedZkpFromUniswap,
                        )
                        .and.to.emit(feeMaster, 'DebtsUpdated')
                        .withArgs(pantherPoolV1.address, sellToken, 0);

                    // Verify protocol debt in sellToken is 0
                    expect(
                        await feeMaster.getDebtForProtocol(sellToken),
                    ).to.equal(0);

                    // Verify nativeTokenReserve increased
                    expect(await feeMaster.nativeTokenReserve()).to.equal(
                        expectedWethFromUniswap,
                    );

                    // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for sellToken
                    expect(
                        pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
                    ).to.have.been.calledWith(
                        sellToken,
                        `-${sellTokenAmount.toString()}`,
                        feeMaster.address,
                    );

                    // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for native token
                    expect(
                        pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
                    ).to.have.been.calledWith(
                        NATIVE_ADDRESS,
                        expectedWethFromUniswap,
                        feeMaster.address,
                    );
                });
            });

            describe('when the swap fullfils the desired native', () => {
                describe('when sell token is not weth', () => {
                    it('should converts collected protocol tokens to native and zkp', async () => {
                        // increasing protocol debt collected in sell token
                        const sellTokenAmount = ethers.utils.parseEther('5');
                        await feeMaster.internalUpdateDebtForProtocol(
                            sellToken,
                            sellTokenAmount,
                        );

                        // Mock Uniswap USDT/native pool rate to 1:1
                        await mockUniswapPoolRate(
                            uniswapV3PoolUSDTNative,
                            1,
                            twapPeriod,
                        );

                        // Mock Uniswap ZKP/native pool rate to 1:1
                        await mockUniswapPoolRate(
                            uniswapV3PoolNativeZkp,
                            1,
                            twapPeriod,
                        );

                        const expectedWethFromUniswap =
                            ethers.utils.parseEther('5'); // Less than target
                        await weth
                            .connect(owner)
                            .transfer(
                                feeMaster.address,
                                expectedWethFromUniswap,
                            );

                        const nativeTokenReserveTarget =
                            ethers.utils.parseEther('1');
                        await feeMaster
                            .connect(owner)
                            .updateNativeTokenReserveTarget(
                                nativeTokenReserveTarget,
                            );

                        const wEthToBeSentToUniswap =
                            expectedWethFromUniswap.sub(
                                nativeTokenReserveTarget,
                            ); // 5e18 - 1e18 = 4e18 wEth
                        const expectedZkpFromUniswap = wEthToBeSentToUniswap; // 1:1 ration between zkp and native
                        await zkp
                            .connect(owner)
                            .transfer(
                                feeMaster.address,
                                expectedZkpFromUniswap,
                            );

                        // Mock PantherPoolV1 adjustVaultAssetsAndUpdateTotalFeeMasterDebt
                        pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt.returns();
                        // Mock the swap function to return (-sellTokenAmount, expectedWethFromUniswap)
                        mockSwap(
                            uniswapV3PoolUSDTNative,
                            sellToken,
                            weth.address,
                            sellTokenAmount,
                            expectedWethFromUniswap,
                        );

                        // Mock the swap function to return (-sellTokenAmount, expectedWethFromUniswap)
                        mockSwap(
                            uniswapV3PoolNativeZkp,
                            weth.address,
                            zkp.address,
                            wEthToBeSentToUniswap,
                            expectedZkpFromUniswap,
                        );

                        // Call rebalanceDebt
                        await expect(
                            feeMaster
                                .connect(owner)
                                .rebalanceDebt(secretHash, sellToken),
                        )
                            .to.emit(feeMaster, 'ProtocolFeeSwapped')
                            .withArgs(
                                sellToken,
                                sellTokenAmount,
                                expectedWethFromUniswap,
                                expectedZkpFromUniswap,
                            )
                            .and.to.emit(feeMaster, 'DebtsUpdated')
                            .withArgs(
                                pantherPoolV1.address,
                                zkp.address,
                                expectedZkpFromUniswap,
                            )
                            .and.to.emit(feeMaster, 'DebtsUpdated')
                            .withArgs(pantherPoolV1.address, sellToken, 0);

                        // Verify protocol debt in sellToken is 0
                        expect(
                            await feeMaster.getDebtForProtocol(sellToken),
                        ).to.equal(0);
                        // Verify protocol debt in sellToken is 0
                        expect(
                            await feeMaster.getDebtForProtocol(zkp.address),
                        ).to.equal(expectedZkpFromUniswap);

                        // Verify nativeTokenReserve increased
                        expect(await feeMaster.nativeTokenReserve()).to.equal(
                            nativeTokenReserveTarget,
                        );

                        // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for sellToken
                        expect(
                            pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
                        ).to.have.been.calledWith(
                            sellToken,
                            `-${sellTokenAmount.toString()}`,
                            feeMaster.address,
                        );

                        // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for native token
                        expect(
                            pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
                        ).to.have.been.calledWith(
                            NATIVE_ADDRESS,
                            expectedWethFromUniswap,
                            feeMaster.address,
                        );

                        // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for zkp token
                        expect(
                            pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
                        ).to.have.been.calledWith(
                            zkp.address,
                            expectedZkpFromUniswap,
                            feeMaster.address,
                        );
                    });
                });
                describe('when sell token is wNative', () => {
                    it('should skip the swap of wNative to naive swap but converts native token to zkp', async () => {
                        sellToken = weth.address;

                        // increasing protocol debt collected in sell token
                        const sellTokenAmount = ethers.utils.parseEther('5');
                        await feeMaster.internalUpdateDebtForProtocol(
                            sellToken,
                            sellTokenAmount,
                        );
                        // assuming sell token have received from Vault
                        await weth
                            .connect(owner)
                            .transfer(feeMaster.address, sellTokenAmount);

                        // skip to swap of native to wEth
                        // Mock Uniswap ZKP/native pool rate to 1:1
                        await mockUniswapPoolRate(
                            uniswapV3PoolNativeZkp,
                            1,
                            twapPeriod,
                        );

                        const nativeTokenReserveTarget =
                            ethers.utils.parseEther('1');
                        await feeMaster
                            .connect(owner)
                            .updateNativeTokenReserveTarget(
                                nativeTokenReserveTarget,
                            );

                        const wEthToBeSentToUniswap = sellTokenAmount.sub(
                            nativeTokenReserveTarget,
                        ); // 5e18 - 1e18 = 4e18 wEth
                        const expectedZkpFromUniswap = wEthToBeSentToUniswap; // 1:1 ration between zkp and native
                        // assuming ZKPs have received from uniswap
                        await zkp
                            .connect(owner)
                            .transfer(
                                feeMaster.address,
                                expectedZkpFromUniswap,
                            );
                        // assuming sell token (wNative) was sent to uniswap to receive ZKP
                        await feeMaster
                            .connect(owner)
                            .withdrawToken(sellToken, wEthToBeSentToUniswap);

                        // Mock PantherPoolV1 adjustVaultAssetsAndUpdateTotalFeeMasterDebt
                        pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt.returns();

                        // Mock the swap function to return (-sellTokenAmount, expectedWethFromUniswap)
                        mockSwap(
                            uniswapV3PoolNativeZkp,
                            sellToken,
                            zkp.address,
                            wEthToBeSentToUniswap,
                            expectedZkpFromUniswap,
                        );

                        // Call rebalanceDebt
                        await expect(
                            feeMaster
                                .connect(owner)
                                .rebalanceDebt(secretHash, sellToken),
                        )
                            .to.emit(feeMaster, 'ProtocolFeeSwapped')
                            .withArgs(
                                sellToken,
                                sellTokenAmount,
                                sellTokenAmount,
                                expectedZkpFromUniswap,
                            )
                            .and.to.emit(feeMaster, 'DebtsUpdated')
                            .withArgs(
                                pantherPoolV1.address,
                                zkp.address,
                                expectedZkpFromUniswap,
                            )
                            .and.to.emit(feeMaster, 'DebtsUpdated')
                            .withArgs(pantherPoolV1.address, sellToken, 0);

                        // Verify protocol debt in sellToken is 0
                        expect(
                            await feeMaster.getDebtForProtocol(sellToken),
                        ).to.equal(0);
                        // Verify protocol debt in sellToken is 0
                        expect(
                            await feeMaster.getDebtForProtocol(zkp.address),
                        ).to.equal(expectedZkpFromUniswap);

                        // Verify nativeTokenReserve increased
                        expect(await feeMaster.nativeTokenReserve()).to.equal(
                            nativeTokenReserveTarget,
                        );

                        // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for sellToken
                        expect(
                            pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
                        ).to.have.been.calledWith(
                            sellToken,
                            `-${sellTokenAmount.toString()}`,
                            feeMaster.address,
                        );

                        // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for native token
                        expect(
                            pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
                        ).to.have.been.calledWith(
                            NATIVE_ADDRESS,
                            nativeTokenReserveTarget,
                            feeMaster.address,
                        );

                        // Verify adjustVaultAssetsAndUpdateTotalFeeMasterDebt called correctly for zkp token
                        expect(
                            pantherPoolV1.adjustVaultAssetsAndUpdateTotalFeeMasterDebt,
                        ).to.have.been.calledWith(
                            zkp.address,
                            expectedZkpFromUniswap,
                            feeMaster.address,
                        );
                    });
                });
            });

            describe('when selling protocol fees collected in zkp token', () => {
                it('should revert', async () => {
                    await expect(
                        feeMaster.rebalanceDebt(secretHash, zkp.address),
                    ).to.be.revertedWith('invalid sell token');
                });
            });

            describe('when selling protocol fees collected in native', () => {
                it('should revert', async () => {
                    await expect(
                        feeMaster.rebalanceDebt(secretHash, NATIVE_ADDRESS),
                    ).to.be.revertedWith('invalid sell token');
                });
            });
        });
    });

    async function mockUniswapPoolTokens(
        pool: FakeContract<IUniswapV3Pool>,
        tokenA: BigNumberish,
        tokenB: BigNumberish,
    ) {
        if (BigNumber.from(tokenA).lt(BigNumber.from(tokenB))) {
            pool.token0.returns(tokenA);
            pool.token1.returns(tokenB);
        } else {
            pool.token0.returns(tokenB);
            pool.token1.returns(tokenA);
        }
    }

    async function mockUniswapPoolRate(
        pool: FakeContract<IUniswapV3Pool>,
        desiredRate: number,
        twapPeriod: number,
    ) {
        /**
         * To achieve a desired rate, we need to determine the averageTick that corresponds to that rate.
         * Since:
         *   rate = 1.0001^averageTick
         *   averageTick = log_{1.0001}(rate)
         *
         * However, Solidity doesn't support floating-point arithmetic, so we approximate using integer ticks.
         *
         * For simplicity, we'll precompute ticks for common rates.
         * Example:
         *   rate = 1 => averageTick = 0
         *   rate = 1.01 => averageTick = 100 (since 1.0001^100 ≈ 1.01005)
         *   rate = 0.99 => averageTick = -100 (since 1.0001^-100 ≈ 0.99005)
         */
        let averageTick: number;

        if (desiredRate === 1) {
            averageTick = 0;
        } else if (desiredRate === 1.01) {
            averageTick = 100;
        } else if (desiredRate === 0.99) {
            averageTick = -100;
        } else if (desiredRate === 1.02) {
            averageTick = 200;
        } else {
            throw new Error('Unsupported desiredRate in mockUniswapPoolRate');
        }

        // Calculate tickCumulatives such that averageTick = (tickCumulatives[1] - tickCumulatives[0]) / twapPeriod
        // Set tickCumulatives[0] = 0
        // tickCumulatives[1] = averageTick * twapPeriod
        const tickCumulatives = [
            ethers.BigNumber.from('0'),
            ethers.BigNumber.from(averageTick * twapPeriod),
        ];

        // Mock the observe function
        pool.observe.returns([
            tickCumulatives,
            [], // secondsPerLiquidityCumulativeX128s, not used
        ]);
    }

    // Helper function to generate the pool key similar to the Solidity PoolKey library
    function getPoolKey(tokenA: string, tokenB: string): string {
        const [sortedA, sortedB] = BigNumber.from(tokenA).lt(
            BigNumber.from(tokenB),
        )
            ? [tokenA, tokenB]
            : [tokenB, tokenA];

        const packed = ethers.utils.solidityPack(
            ['address', 'address'],
            [sortedA, sortedB],
        );
        return ethers.utils.keccak256(packed);
    }
});
