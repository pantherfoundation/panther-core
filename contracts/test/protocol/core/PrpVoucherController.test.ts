// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber, ContractFactory} from 'ethers';
import {ethers} from 'hardhat';

import {PrpVoucherController as PrpVoucherControllerType} from '../../../types/contracts/PrpVoucherController';
import {
    generateExtraInputsHash,
    sampleProof,
} from '../data/samples/pantherPool.data';
import {
    generatePrivateMessage,
    TransactionTypes,
} from '../data/samples/transactionNote.data';

const VOUCHER_WITH_PREDEFINED_REWARD = ethers.utils
    .id('VOUCHER_WITH_PREDEFINED_REWARD')
    .slice(0, 10);

const VOUCHER_WITH_ANY_REWARD = ethers.utils
    .id('VOUCHER_WITH_ANY_REWARD')
    .slice(0, 10);

const amount = BigNumber.from('1000');
const zeroValue = BigNumber.from('1');
const disabledVoucherType = '0xdeadbeef';

const transactionOptions: number = 0;
const paymasterCompensation: number = 0;
const privateMessages: string = generatePrivateMessage(
    TransactionTypes.prpClaim,
);

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

describe('PrpVoucherController', function () {
    let owner: SignerWithAddress,
        allowedContract: SignerWithAddress,
        user: SignerWithAddress;
    let prpVoucherController: PrpVoucherControllerType;
    let PrpVoucherController: ContractFactory;
    let inputs;
    let secretHash;
    let fakePantherTrees: FakeContract,
        feeMaster: FakeContract,
        fakeToken: FakeContract;

    beforeEach(async function () {
        secretHash = ethers.utils.id('test_secret');
        [owner, allowedContract, user] = await ethers.getSigners();

        PrpVoucherController = await ethers.getContractFactory(
            'MockPrpVoucherController',
        );

        fakePantherTrees = await smock.fake('IUtxoInserter');

        // Set up the function return values
        fakePantherTrees.insertPrpClaimUtxo.returns({
            zAccountUtxoQueueId: 0,
            zAccountUtxoIndexInQueue: 0,
            zAccountUtxoBusQueuePos: 0,
        });

        feeMaster = await smock.fake('FeeMaster');
        fakeToken = await smock.fake('ERC20');

        prpVoucherController = (await PrpVoucherController.deploy(
            fakePantherTrees.address,
            feeMaster.address,
            fakeToken.address,
        )) as PrpVoucherControllerType;

        await prpVoucherController.deployed();
    });

    describe('Deployment', function () {
        it('sets the correct owner, pool contract, and verifier addresses', async function () {
            expect(await prpVoucherController.PANTHER_TREES()).to.equal(
                fakePantherTrees.address,
            );
            expect(await prpVoucherController.FEE_MASTER()).to.equal(
                feeMaster.address,
            );
            expect(await prpVoucherController.ZKP_TOKEN()).to.equal(
                fakeToken.address,
            );
        });

        it('reverts with zero address', async function () {
            const PrpVoucherController = await ethers.getContractFactory(
                'PrpVoucherController',
            );

            await expect(
                PrpVoucherController.deploy(
                    ethers.constants.AddressZero,
                    feeMaster.address,
                    fakeToken.address,
                ),
            ).to.be.revertedWith('init::PrpVoucherController:zero address');

            await expect(
                PrpVoucherController.deploy(
                    fakePantherTrees.address,
                    ethers.constants.AddressZero,
                    fakeToken.address,
                ),
            ).to.be.revertedWith(
                'init::TransactionChargesHandler:zero address',
            );

            await expect(
                PrpVoucherController.deploy(
                    fakePantherTrees.address,
                    feeMaster.address,
                    ethers.constants.AddressZero,
                ),
            ).to.be.revertedWith(
                'init::TransactionChargesHandler:zero address',
            );
        });
    });

    describe('Setting reward terms', function () {
        it('sets voucher reward terms with valid voucher types', async function () {
            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount,
                    amount,
                    true,
                );

            const rewardTerms = await prpVoucherController.voucherTerms(
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
                prpVoucherController
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
            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount,
                    amount,
                    true,
                );

            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    ethers.utils.id('test_secret'),
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount,
                    amount,
                    true,
                );

            const rewardTerms = await prpVoucherController.voucherTerms(
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
            // prpVoucherController = (await PrpVoucherController.deploy(
            //     owner.address,
            //     poolContract.address,
            // )) as PrpVoucherControllerType;
            //
            // await prpVoucherController.deployed();

            // Set the reward terms for the AMM_ADD_LIQUIDITY_VOUCHER_TYPE
            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount.mul(2),
                    amount,
                    true,
                );

            await prpVoucherController
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
                prpVoucherController
                    .connect(user)
                    .generateRewards(
                        secretHash,
                        amount,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    ),
            ).to.be.revertedWith(
                'PrpVoucherController: Inactive or invalid voucher type',
            );
        });

        it('generates rewards of predefined amount', async function () {
            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                amount.add(zeroValue),
            );

            expect(
                (
                    await prpVoucherController.voucherTerms(
                        allowedContract.address,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    )
                ).rewardsGranted,
            ).to.equal(amount);

            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                amount.add(zeroValue).add(amount),
            );
        });

        it('generates rewards of any amount', async function () {
            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount.div(2),
                    VOUCHER_WITH_ANY_REWARD,
                );

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue),
            );

            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(secretHash, amount, VOUCHER_WITH_ANY_REWARD);

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue).add(amount),
            );
        });

        it('generates rewards of any amount and predefined', async function () {
            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                amount.add(zeroValue),
            );

            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount.div(2),
                    VOUCHER_WITH_ANY_REWARD,
                );

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                amount.div(2).add(zeroValue).add(amount),
            );
        });

        it('reverts when generating reward vouchers with disabled voucher types', async function () {
            await expect(
                prpVoucherController
                    .connect(allowedContract)
                    .generateRewards(secretHash, amount, disabledVoucherType),
            ).to.be.revertedWith(
                'PrpVoucherController: Inactive or invalid voucher type',
            );
        });

        it('does not generate a reward voucher beyond the reward limit', async function () {
            const terms = await prpVoucherController.voucherTerms(
                allowedContract.address,
                VOUCHER_WITH_PREDEFINED_REWARD,
            );

            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    terms.rewardsGranted.add(amount),
                    amount,
                    true,
                );

            // this reward is within the limit and should succeed
            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            // This call should not generate reward
            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount.mul(2),
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            const newTerms = await prpVoucherController.voucherTerms(
                allowedContract.address,
                VOUCHER_WITH_PREDEFINED_REWARD,
            );

            expect(newTerms.rewardsGranted).to.equal(newTerms.limit);
        });

        it('properly updates rewards granted when generating reward vouchers', async function () {
            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(
                (
                    await prpVoucherController.voucherTerms(
                        allowedContract.address,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    )
                ).rewardsGranted,
            ).to.equal(amount);

            await prpVoucherController
                .connect(allowedContract)
                .generateRewards(
                    secretHash,
                    amount,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                );

            expect(
                (
                    await prpVoucherController.voucherTerms(
                        allowedContract.address,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    )
                ).rewardsGranted,
            ).to.equal(amount.mul(2));
        });
    });

    describe('Claiming rewards', () => {
        const secretHash2 = ethers.utils.id('test_claiig_secret');

        beforeEach(async function () {
            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount.mul(10),
                    amount,
                    true,
                );

            await prpVoucherController
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
                [transactionOptions, paymasterCompensation, privateMessages],
            );
        });

        // it('rejact claims if early', async function () {
        //     await expect(
        //         await prpVoucherController
        //             .connect(user)
        //             .accountRewards(
        //                 inputs,
        //                 sampleProof,
        //                 transactionOptions,
        //                 paymasterCompensation,
        //                 privateMessages,
        //             ),
        //     ).to.emit(prpVoucherController, 'RewardClaimed');
        //
        //     expect(await prpVoucherController.balance(secretHash)).to.equal(
        //         BigNumber.from('0'),
        //     );
        // });

        it('claims the reward voucher', async function () {
            inputs[3] = ((await getBlockTimestamp()) + 3).toString();
            await expect(
                await prpVoucherController
                    .connect(user)
                    .accountRewards(
                        inputs,
                        sampleProof,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
            ).to.emit(prpVoucherController, 'RewardClaimed');

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                BigNumber.from('0'),
            );
        });

        it('reverts when trying to claim a reward voucher with no balance', async function () {
            inputs[3] = ((await getBlockTimestamp()) + 3).toString();
            const noBalanceSecretHash = ethers.utils.id('no_balance_secret');
            inputs[15] = noBalanceSecretHash;
            await expect(
                prpVoucherController
                    .connect(user)
                    .accountRewards(
                        inputs,
                        sampleProof,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
            ).to.be.revertedWith('PrpVoucherController: No reward to claim');
        });
    });

    describe('Repetitive claiming and generation of rewards', () => {
        beforeEach(async function () {
            // Set the reward terms for the AMM_ADD_LIQUIDITY_VOUCHER_TYPE
            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_PREDEFINED_REWARD,
                    amount.mul(2),
                    amount,
                    true,
                );
            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_ANY_REWARD,
                    amount.mul(2),
                    0,
                    true,
                );

            inputs = await claimRewardsInputs();
            secretHash = ethers.utils.id('all_rewards');
            inputs[3] = ((await getBlockTimestamp()) + 3).toString();
            inputs[15] = secretHash;
            inputs[4] = amount.add(zeroValue);
            inputs[0] = generateExtraInputsHash(
                ['uint32', 'uint96', 'bytes'],
                [transactionOptions, paymasterCompensation, privateMessages],
            );
        });

        it('generates and claims reward vouchers from different vouchers', async function () {
            const hashBalanceBefore =
                await prpVoucherController.balance(secretHash);
            await expect(
                prpVoucherController
                    .connect(allowedContract)
                    .generateRewards(
                        secretHash,
                        amount,
                        VOUCHER_WITH_PREDEFINED_REWARD,
                    ),
            ).to.emit(prpVoucherController, 'RewardVoucherGenerated');

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                hashBalanceBefore.add(zeroValue).add(amount),
            );
            await expect(
                prpVoucherController
                    .connect(user)
                    .accountRewards(
                        inputs,
                        sampleProof,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
            ).to.emit(prpVoucherController, 'RewardClaimed');

            expect(await prpVoucherController.balance(secretHash)).to.equal(
                zeroValue,
            );

            await prpVoucherController
                .connect(owner)
                .updateVoucherTerms(
                    allowedContract.address,
                    VOUCHER_WITH_ANY_REWARD,
                    amount.mul(2),
                    0,
                    true,
                );
        });
    });
});
