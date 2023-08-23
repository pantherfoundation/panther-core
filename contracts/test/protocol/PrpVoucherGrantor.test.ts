// SPDX-License-Identifier: MIT

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber, ContractFactory} from 'ethers';
import {ethers} from 'hardhat';

import {PrpVoucherGrantor as PrpVoucherGrantorType} from '../../types/contracts/PrpVoucherGrantor';

const VOUCHER_WITH_PREDEFINED_REWARD = ethers.utils
    .id('VOUCHER_WITH_PREDEFINED_REWARD')
    .slice(0, 10);

const VOUCHER_WITH_ANY_REWARD = ethers.utils
    .id('VOUCHER_WITH_ANY_REWARD')
    .slice(0, 10);

const secretHash = ethers.utils.id('test_secret');
const amount = BigNumber.from('1000');
const zeroValue = BigNumber.from('1');
const disabledVoucherType = '0xdeadbeef';
const proof = ethers.utils.id('proof');

describe.only('PrpVoucherGrantor', function () {
    let owner: SignerWithAddress,
        poolContract: SignerWithAddress,
        allowedContract: SignerWithAddress,
        user: SignerWithAddress;
    let prpVoucherGrantor: PrpVoucherGrantorType;
    let PrpVoucherGrantor: ContractFactory;

    before(async function () {
        [owner, poolContract, allowedContract, user] =
            await ethers.getSigners();

        PrpVoucherGrantor = await ethers.getContractFactory(
            'PrpVoucherGrantor',
        );

        prpVoucherGrantor = (await PrpVoucherGrantor.deploy(
            owner.address,
            poolContract.address,
        )) as PrpVoucherGrantorType;

        await prpVoucherGrantor.deployed();
    });

    describe('Deployment', function () {
        it('sets the correct owner, pool contract, and verifier addresses', async function () {
            expect(await prpVoucherGrantor.OWNER()).to.equal(owner.address);
            expect(await prpVoucherGrantor.POOL_CONTRACT()).to.equal(
                poolContract.address,
            );
        });

        it('reverts with zero address', async function () {
            const PrpVoucherGrantor = await ethers.getContractFactory(
                'PrpVoucherGrantor',
            );

            await expect(
                PrpVoucherGrantor.deploy(
                    ethers.constants.AddressZero,
                    poolContract.address,
                ),
            ).to.be.revertedWith('ImmOwn: zero owner address');

            await expect(
                PrpVoucherGrantor.deploy(
                    owner.address,
                    ethers.constants.AddressZero,
                ),
            ).to.be.revertedWith('UNEXPECTED_ZERO_ADDRESS');
        });
    });

    describe('Setting reward terms', function () {
        it('only allows the owner to set voucher reward terms', async function () {
            await expect(
                prpVoucherGrantor
                    .connect(user)
                    .updateVoucherTerms(
                        allowedContract.address,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                        amount,
                        amount,
                        true,
                    ),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('sets voucher reward terms with valid voucher types', async function () {
            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount,
                    amount,
                    true,
                );

            const rewardTerms = await prpVoucherGrantor.voucherTerms(
                allowedContract.address,
                VOUCHER_WITH_PREDEFINED_REWARD,
            );
            expect(rewardTerms.rewardsGranted).to.equal(0);
            expect(rewardTerms.limit).to.equal(amount);
            expect(rewardTerms.amount).to.equal(amount);
            expect(rewardTerms.enabled).to.equal(true);
        });

        it('reverts when allowed contract address is zero', async function () {
            await expect(
                prpVoucherGrantor
                    .connect(owner)
                    .updateVoucherTerms(
                        ethers.constants.AddressZero,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                        amount,
                        amount,
                        true,
                    ),
            ).to.be.revertedWith('UNEXPECTED_ZERO_ADDRESS');
        });

        it('should not reset rewards generated', async function () {
            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount,
                    amount,
                    true,
                );

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    ethers.utils.id('test_secret'),
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount,
                    amount,
                    true,
                );

            const rewardTerms = await prpVoucherGrantor.voucherTerms(
                allowedContract.address,
                VOUCHER_WITH_PREDEFINED_REWARD,
            );
            expect(rewardTerms.rewardsGranted).to.equal(amount);
            expect(rewardTerms.limit).to.equal(amount);
            expect(rewardTerms.amount).to.equal(amount);
            expect(rewardTerms.enabled).to.equal(true);
        });
    });

    describe('Generating rewards', function () {
        beforeEach(async function () {
            prpVoucherGrantor = (await PrpVoucherGrantor.deploy(
                owner.address,
                poolContract.address,
            )) as PrpVoucherGrantorType;

            await prpVoucherGrantor.deployed();

            // Set the reward terms for the AMM_ADD_LIQUIDITY_VOUCHER_TYPE
            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount.mul(2),
                    amount,
                    true,
                );

            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_ANY_REWARD,
                    amount.mul(2),
                    0,
                    true,
                );
        });

        it('allows only allowed contracts to generate rewards', async function () {
            await expect(
                prpVoucherGrantor
                    .connect(user)
                    .generateReward(
                        secretHash,
                        amount,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    ),
            ).to.be.revertedWith(
                'PrpVoucherGrantor: Inactive or invalid voucher type',
            );
        });

        it('generates rewards of predefined amount', async function () {
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.add(zeroValue),
            );

            expect(
                (
                    await prpVoucherGrantor.voucherTerms(
                        allowedContract.address,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    )
                ).rewardsGranted,
            ).to.equal(amount);

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.add(zeroValue).add(amount),
            );
        });

        it('generates rewards of any amount', async function () {
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount.div(2),
                    VOUCHER_WITH_ANY_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue),
            );

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(secretHash, amount, VOUCHER_WITH_ANY_REWARD);

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue).add(amount),
            );
        });

        it('generates rewards of any amount and predefined', async function () {
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.add(zeroValue),
            );

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount.div(2),
                    VOUCHER_WITH_ANY_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue).add(amount),
            );
        });

        it('reverts when generating reward vouchers with disabled voucher types', async function () {
            await expect(
                prpVoucherGrantor
                    .connect(allowedContract)
                    .generateReward(secretHash, amount, disabledVoucherType),
            ).to.be.revertedWith(
                'PrpVoucherGrantor: Inactive or invalid voucher type',
            );
        });

        it('does not generate a reward voucher beyond the reward limit', async function () {
            const terms = await prpVoucherGrantor.voucherTerms(
                allowedContract.address,
                VOUCHER_WITH_PREDEFINED_REWARD,
            );

            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    terms.rewardsGranted.add(amount),
                    amount,
                    true,
                );

            // this reward is within the limit and should succeed
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            // This call should not generate reward
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount.mul(2),
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            const newTerms = await prpVoucherGrantor.voucherTerms(
                allowedContract.address,
                VOUCHER_WITH_PREDEFINED_REWARD,
            );

            expect(newTerms.rewardsGranted).to.equal(newTerms.limit);
        });

        it('properly updates rewards granted when generating reward vouchers', async function () {
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(
                (
                    await prpVoucherGrantor.voucherTerms(
                        allowedContract.address,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    )
                ).rewardsGranted,
            ).to.equal(amount);

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(
                (
                    await prpVoucherGrantor.voucherTerms(
                        allowedContract.address,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    )
                ).rewardsGranted,
            ).to.equal(amount.mul(2));
        });
    });

    describe('Claiming rewards', () => {
        beforeEach(async function () {
            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount.mul(10),
                    amount,
                    true,
                );

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );
        });

        it('claims the reward voucher', async function () {
            await prpVoucherGrantor
                .connect(user)
                .claimRewards(secretHash, proof);

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                zeroValue,
            );
        });

        it('reverts when trying to claim a reward voucher with no balance', async function () {
            const noBalanceSecretHash = ethers.utils.id('no_balance_secret');
            await expect(
                prpVoucherGrantor
                    .connect(user)
                    .claimRewards(noBalanceSecretHash, proof),
            ).to.be.revertedWith('PrpVoucherGrantor: No reward to claim');
        });
    });

    describe('Repetitive claiming and generation of rewards', () => {
        beforeEach(async function () {
            prpVoucherGrantor = (await PrpVoucherGrantor.deploy(
                owner.address,
                poolContract.address,
            )) as PrpVoucherGrantorType;

            await prpVoucherGrantor.deployed();

            // Set the reward terms for the AMM_ADD_LIQUIDITY_VOUCHER_TYPE
            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount.mul(2),
                    amount,
                    true,
                );
            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_ANY_REWARD,
                    amount.mul(2),
                    0,
                    true,
                );
        });

        it('generates and claims reward vouchers from different vouchers', async function () {
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.add(zeroValue),
            );

            await prpVoucherGrantor
                .connect(user)
                .claimRewards(secretHash, proof);

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                zeroValue,
            );

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateReward(
                    secretHash,
                    amount.div(2),
                    VOUCHER_WITH_ANY_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue),
            );

            await prpVoucherGrantor
                .connect(user)
                .claimRewards(secretHash, proof);

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                zeroValue,
            );
        });
    });
});
