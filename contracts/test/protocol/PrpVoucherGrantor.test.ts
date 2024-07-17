// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber, ContractFactory} from 'ethers';
import {ethers} from 'hardhat';

import {PrpVoucherGrantor as PrpVoucherGrantorType} from '../../types/contracts/PrpVoucherGrantor';

import {
    generateExtraInputsHash,
    sampleProof,
} from './data/samples/pantherPool.data';
import {BYTES32_ZERO} from './shared';

const VOUCHER_WITH_PREDEFINED_REWARD = ethers.utils
    .id('VOUCHER_WITH_PREDEFINED_REWARD')
    .slice(0, 10);

const VOUCHER_WITH_ANY_REWARD = ethers.utils
    .id('VOUCHER_WITH_ANY_REWARD')
    .slice(0, 10);

const amount = BigNumber.from('1000');
const zeroValue = BigNumber.from('1');
const disabledVoucherType = '0xdeadbeef';

const getSnarkFriendlyBytes = (): string => {
    // Mock function to generate snark-friendly bytes. Replace with actual implementation.
    return ethers.utils.hexlify(ethers.utils.randomBytes(32));
};

const getBlockTimestamp = async (): Promise<number> => {
    const block = await ethers.provider.getBlock('latest');
    return block.timestamp;
};

export const claimRewardsInputs = async () => {
    const chainId = (await ethers.provider.getNetwork()).chainId;

    return [
        getSnarkFriendlyBytes(), // extraInputsHash (inputs[0])
        ethers.utils.parseEther('0').toString(), // addedAmountZkp (inputs[1])
        ethers.utils.parseEther('1').toString(), // chargedAmountZkp (inputs[2])
        (await getBlockTimestamp()).toString(), // createTime (inputs[3])
        ethers.utils.parseEther('1000').toString(), // depositAmountPrp (inputs[4])
        ethers.utils.parseEther('0').toString(), // withdrawAmountPrp (inputs[5])
        getSnarkFriendlyBytes(), // utxoCommitmentPrivatePart (inputs[6])
        getSnarkFriendlyBytes(), // utxoSpendPubKeyX (inputs[7])
        getSnarkFriendlyBytes(), // utxoSpendPubKeyY (inputs[8])
        '1', // zAssetScale (inputs[9])
        getSnarkFriendlyBytes(), // zAccountUtxoInNullifier (inputs[10])
        getSnarkFriendlyBytes(), // zAccountUtxoOutCommitment (inputs[11])
        chainId.toString(), // zNetworkChainId (inputs[12])
        ethers.BigNumber.from(0).toString(), // staticTreeMerkleRoot (inputs[13])
        getSnarkFriendlyBytes(), // forestMerkleRoot (inputs[14])
        getSnarkFriendlyBytes(), // saltHash (inputs[15])
        getSnarkFriendlyBytes(), // magicalConstraint (inputs[16])
    ];
};

describe('PrpVoucherGrantor', function () {
    let owner: SignerWithAddress,
        poolContract: SignerWithAddress,
        allowedContract: SignerWithAddress,
        user: SignerWithAddress;
    let prpVoucherGrantor: PrpVoucherGrantorType;
    let PrpVoucherGrantor: ContractFactory;
    let inputs;
    let secretHash;

    before(async function () {
        secretHash = ethers.utils.id('test_secret');
        [owner, poolContract, allowedContract, user] =
            await ethers.getSigners();

        PrpVoucherGrantor =
            await ethers.getContractFactory('PrpVoucherGrantor');

        prpVoucherGrantor = (await PrpVoucherGrantor.deploy(
            owner.address,
            poolContract.address,
        )) as PrpVoucherGrantorType;

        await prpVoucherGrantor.deployed();
    });

    describe('Deployment', function () {
        it('sets the correct owner, pool contract, and verifier addresses', async function () {
            expect(await prpVoucherGrantor.OWNER()).to.equal(owner.address);
            expect(await prpVoucherGrantor.PANTHER_POOL_V1()).to.equal(
                poolContract.address,
            );
        });

        it('reverts with zero address', async function () {
            const PrpVoucherGrantor =
                await ethers.getContractFactory('PrpVoucherGrantor');

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
                .generateRewards(
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
                    .generateRewards(
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
                .generateRewards(
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
                .generateRewards(
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
                .generateRewards(
                    secretHash,
                    amount.div(2),
                    VOUCHER_WITH_ANY_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue),
            );

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateRewards(secretHash, amount, VOUCHER_WITH_ANY_REWARD);

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue).add(amount),
            );
        });

        it('generates rewards of any amount and predefined', async function () {
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                amount.add(zeroValue),
            );

            await prpVoucherGrantor
                .connect(allowedContract)
                .generateRewards(
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
                    .generateRewards(secretHash, amount, disabledVoucherType),
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
                .generateRewards(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            // This call should not generate reward
            await prpVoucherGrantor
                .connect(allowedContract)
                .generateRewards(
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
                .generateRewards(
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
                .generateRewards(
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
        const secretHash2 = ethers.utils.id('test_claiig_secret');
        let pool;

        beforeEach(async function () {
            pool = await smock.fake('PantherPoolV1');

            PrpVoucherGrantor =
                await ethers.getContractFactory('PrpVoucherGrantor');

            prpVoucherGrantor = (await PrpVoucherGrantor.deploy(
                owner.address,
                pool.address,
            )) as PrpVoucherGrantorType;

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
                .generateRewards(
                    secretHash2,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            inputs = await claimRewardsInputs();

            inputs[15] = secretHash2;
            inputs[4] = amount.add(zeroValue);
            inputs[0] = generateExtraInputsHash(
                ['uint32', 'uint96', 'bytes'],
                [BYTES32_ZERO, BYTES32_ZERO, BYTES32_ZERO],
            );
        });

        it('claims the reward voucher', async function () {
            await expect(
                await prpVoucherGrantor
                    .connect(user)
                    .claimRewards(
                        inputs,
                        sampleProof,
                        BYTES32_ZERO,
                        BYTES32_ZERO,
                        BYTES32_ZERO,
                    ),
            ).to.emit(prpVoucherGrantor, 'RewardClaimed');

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                BigNumber.from('0'),
            );
        });

        it('reverts when trying to claim a reward voucher with no balance', async function () {
            const noBalanceSecretHash = ethers.utils.id('no_balance_secret');
            inputs[15] = noBalanceSecretHash;
            await expect(
                prpVoucherGrantor
                    .connect(user)
                    .claimRewards(
                        inputs,
                        sampleProof,
                        BYTES32_ZERO,
                        BYTES32_ZERO,
                        BYTES32_ZERO,
                    ),
            ).to.be.revertedWith('PrpVoucherGrantor: No reward to claim');
        });
    });

    describe('Repetitive claiming and generation of rewards', () => {
        beforeEach(async function () {
            //     prpVoucherGrantor = (await PrpVoucherGrantor.deploy(
            //         owner.address,
            //         poolContract.address,
            //     )) as PrpVoucherGrantorType;
            //
            //     await prpVoucherGrantor.deployed();
            //
            //     // Set the reward terms for the AMM_ADD_LIQUIDITY_VOUCHER_TYPE
            //     await prpVoucherGrantor
            //         .connect(owner)
            //         .updateVoucherTerms(
            //             allowedContract.address,
            //             VOUCHER_WITH_PREDEFINED_REWARD,
            //             amount.mul(2),
            //             amount,
            //             true,
            //         );
            //     await prpVoucherGrantor
            //         .connect(owner)
            //         .updateVoucherTerms(
            //             allowedContract.address,
            //             VOUCHER_WITH_ANY_REWARD,
            //             amount.mul(2),
            //             0,
            //             true,
            //         );

            inputs = await claimRewardsInputs();
            secretHash = ethers.utils.id('all_rewards');
            inputs[15] = secretHash;
            inputs[4] = amount.add(zeroValue);
            inputs[0] = generateExtraInputsHash(
                ['uint32', 'uint96', 'bytes'],
                [BYTES32_ZERO, BYTES32_ZERO, BYTES32_ZERO],
            );
        });

        it('generates and claims reward vouchers from different vouchers', async function () {
            const hashBalanceBefore =
                await prpVoucherGrantor.balance(secretHash);
            await expect(
                prpVoucherGrantor
                    .connect(allowedContract)
                    .generateRewards(
                        secretHash,
                        amount,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    ),
            ).to.emit(prpVoucherGrantor, 'RewardVoucherGenerated');

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                hashBalanceBefore.add(zeroValue).add(amount),
            );
            await expect(
                prpVoucherGrantor
                    .connect(user)
                    .claimRewards(
                        inputs,
                        sampleProof,
                        BYTES32_ZERO,
                        BYTES32_ZERO,
                        BYTES32_ZERO,
                    ),
            ).to.emit(prpVoucherGrantor, 'RewardClaimed');

            // expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
            //     zero,
            // );

            await prpVoucherGrantor
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_ANY_REWARD,
                    amount.mul(2),
                    0,
                    true,
                );

            await expect(
                prpVoucherGrantor
                    .connect(allowedContract)
                    .generateRewards(
                        secretHash,
                        amount.div(2),
                        VOUCHER_WITH_ANY_REWARD,
                    ),
            ).to.emit(prpVoucherGrantor, 'RewardVoucherGenerated');

            const currrentSecretHashBalance =
                await prpVoucherGrantor.balance(secretHash);

            expect(currrentSecretHashBalance).to.equal(
                amount.div(2).add(zeroValue),
            );

            inputs[4] = currrentSecretHashBalance;

            await expect(
                prpVoucherGrantor
                    .connect(user)
                    .claimRewards(
                        inputs,
                        sampleProof,
                        BYTES32_ZERO,
                        BYTES32_ZERO,
                        BYTES32_ZERO,
                    ),
            ).to.emit(prpVoucherGrantor, 'RewardClaimed');

            expect(await prpVoucherGrantor.balance(secretHash)).to.equal(
                zeroValue,
            );
        });
    });
});
