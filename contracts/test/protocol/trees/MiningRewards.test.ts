// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {smock, FakeContract} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {
    IERC20,
    IDebtSettlement,
    MockMiningRewards,
} from '../../../types/contracts';
import {getBlockTimestamp} from '../helpers/hardhat';

describe('MiningRewards', function () {
    let miningRewards: MockMiningRewards;
    let feeMaster: FakeContract<IDebtSettlement>;
    let rewardToken: FakeContract<IERC20>;
    let miner: SignerWithAddress, receiver: SignerWithAddress;

    before(async () => {
        [, miner, receiver] = await ethers.getSigners();
    });

    beforeEach(async function () {
        feeMaster = await smock.fake('IDebtSettlement');
        rewardToken = await smock.fake('IERC20');

        const MiningRewardsFactory =
            await ethers.getContractFactory('MockMiningRewards');

        miningRewards = await MiningRewardsFactory.deploy(
            feeMaster.address,
            rewardToken.address,
            1,
        );
    });

    it('should account miner rewards', async function () {
        const rewardAmount = ethers.utils.parseEther('10');
        const queueId = 1;

        await expect(
            miningRewards.internalAccountMinerRewards(
                queueId,
                miner.address,
                rewardAmount,
            ),
        )
            .to.emit(miningRewards, 'MinerRewardAccounted')
            .withArgs(queueId, miner.address, rewardAmount);

        expect(await miningRewards.rewards(miner.address)).to.equal(
            rewardAmount,
        );
    });

    it("should claim miner rewards and reset the miner's reward to zero", async function () {
        const rewardAmount = ethers.utils.parseEther('10');
        const queueId = 1;

        // Account the miner's rewards
        await miningRewards.internalAccountMinerRewards(
            queueId,
            miner.address,
            rewardAmount,
        );

        feeMaster['payOff(address,address,uint256)']
            .whenCalledWith(rewardToken.address, receiver.address, rewardAmount)
            .returns(rewardAmount);

        const blockTime = await getBlockTimestamp();
        await expect(
            miningRewards.internalClaimMinerRewards(
                miner.address,
                receiver.address,
            ),
        )
            .to.emit(miningRewards, 'MinerRewardClaimed')
            .withArgs(blockTime + 1, miner.address, rewardAmount);

        expect(await miningRewards.rewards(miner.address)).to.equal(0);
    });

    it('should revert if there are no rewards to claim', async function () {
        // Attempt to claim rewards with none available
        await expect(
            miningRewards.internalClaimMinerRewards(
                miner.address,
                receiver.address,
            ),
        ).to.be.revertedWith('MR:E1');
    });
});
