// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {FakeContract, smock} from '@defi-wonderland/smock';
import {expect} from 'chai';
import {Signer} from 'ethers';
import {ethers} from 'hardhat';

import {mineBlock} from '../../lib/hardhat';
import {getBlockNumber} from '../../lib/provider';
import {ZkpReserveController, TokenMock} from '../../types/contracts';

const secret = ethers.utils.formatBytes32String('test');
const voucherType = '0x53a1eb85';

describe('ZkpReserveController', function () {
    let zkpReserveController: ZkpReserveController;
    let owner: Signer, user: Signer, nonOwner: Signer;
    let zkpToken: TokenMock, pantherPool: FakeContract;

    before(async () => {
        [owner, user, nonOwner] = await ethers.getSigners();

        const Token = await ethers.getContractFactory('TokenMock');
        zkpToken = (await Token.connect(owner).deploy()) as TokenMock;

        pantherPool = await smock.fake('PrpVoucherController');
    });

    beforeEach(async function () {
        const ZkpReserveControllerFactory = await ethers.getContractFactory(
            'ZkpReserveController',
        );
        zkpReserveController = (await ZkpReserveControllerFactory.deploy(
            await owner.getAddress(), // owner
            zkpToken.address,
            pantherPool.address,
        )) as ZkpReserveController;

        // Filling up ZkpReserveController with ZKP tokens
        await zkpToken
            .connect(owner)
            .transfer(
                zkpReserveController.address,
                ethers.utils.parseEther('10000'),
            );
    });

    describe('Deployment', function () {
        it('should deploy with correct initial settings', async function () {
            expect(await zkpReserveController.ZKP_TOKEN()).to.equal(
                zkpToken.address,
            );
            expect(await zkpReserveController.OWNER()).to.equal(
                await owner.getAddress(),
            );
            expect(await zkpReserveController.PANTHER_POOL()).to.equal(
                pantherPool.address,
            );
        });
    });

    describe('Configuration', function () {
        const releasablePerBlock = ethers.utils.parseUnits('20', '12');
        const minRewardableAmount = ethers.utils.parseUnits('200', '12');

        it('should update configuration correctly', async function () {
            await zkpReserveController.updateParams(
                releasablePerBlock,
                minRewardableAmount,
            );
            const {
                _releasablePerBlock,
                _minRewardableAmount,
                _totalReleased,
                _blockAtLastUpdate,
                _scAccumulatedAccrual,
            } = await zkpReserveController.getRewardStats();

            expect(_releasablePerBlock).to.equal(releasablePerBlock);
            expect(_minRewardableAmount).to.equal(minRewardableAmount);
            expect(_totalReleased).to.equal(0);
            expect(_scAccumulatedAccrual).to.equal(0);
            expect(_blockAtLastUpdate).to.equal(await getBlockNumber());
        });

        it('should revert when non-owner tries to update parameters', async function () {
            await expect(
                zkpReserveController.connect(nonOwner).updateParams(20, 200),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should emit RewardParamsUpdated event when params are updated', async function () {
            await expect(
                zkpReserveController.updateParams(
                    releasablePerBlock,
                    minRewardableAmount,
                ),
            )
                .to.emit(zkpReserveController, 'RewardParamsUpdated')
                .withArgs(
                    releasablePerBlock,
                    minRewardableAmount,
                    (await getBlockNumber()) + 1,
                );
        });
    });

    describe('Refill functionality', function () {
        const releasablePerBlock = ethers.utils.parseEther('20');
        const minRewardableAmount = ethers.utils.parseEther('30');

        it('should release tokens correctly', async function () {
            await zkpReserveController.updateParams(
                releasablePerBlock,
                minRewardableAmount,
            );

            const releasableAmount = releasablePerBlock;

            console.log(
                'ZkpReserveController.releasableAmount()',
                await zkpReserveController.releasableAmount(),
            );

            await expect(zkpReserveController.connect(user).releaseZkps(secret))
                .to.emit(zkpReserveController, 'ZkpReservesReleased')
                .withArgs(secret, releasableAmount);

            const pantherPoolBalance = await zkpToken.balanceOf(
                pantherPool.address,
            );
            expect(pantherPoolBalance).to.equal(releasableAmount);
        });

        it('should not reward if released amount is below minimalRewardedAmount', async function () {
            await zkpReserveController.updateParams(
                releasablePerBlock,
                minRewardableAmount,
            );

            await zkpReserveController.connect(user).releaseZkps(secret);
            expect(pantherPool.generateRewards).not.to.have.been.called;
        });

        it('should reward if released amount is above minimalRewardedAmount', async function () {
            await zkpReserveController.updateParams(releasablePerBlock, 1e12);

            await zkpReserveController.connect(user).releaseZkps(secret);

            expect(pantherPool.generateRewards).to.have.been.calledWith(
                secret,
                0,
                voucherType,
            );
        });

        it('should calculate releasable amount correctly over time', async function () {
            await zkpReserveController.updateParams(
                releasablePerBlock,
                minRewardableAmount,
            );

            await mineBlock();
            expect(await zkpReserveController.releasableAmount()).to.to.eq(
                releasablePerBlock,
            );

            await mineBlock();
            expect(await zkpReserveController.releasableAmount()).to.to.eq(
                releasablePerBlock.mul(2),
            );

            await mineBlock();
            expect(await zkpReserveController.releasableAmount()).to.to.eq(
                releasablePerBlock.mul(3),
            );

            // increase the releasablePerBlock

            const releasablePerBlockFirstUpdate = releasablePerBlock.add(
                ethers.utils.parseEther('10'),
            );
            await zkpReserveController.updateParams(
                releasablePerBlockFirstUpdate,
                minRewardableAmount,
            );
            await mineBlock();

            expect(await zkpReserveController.releasableAmount()).to.to.eq(
                releasablePerBlock.mul(4).add(releasablePerBlockFirstUpdate),
            );

            // decrease the releasablePerBlock
            const releasablePerBlockSecondUpdate = releasablePerBlock.sub(
                ethers.utils.parseEther('10'),
            );
            await zkpReserveController.updateParams(
                releasablePerBlockSecondUpdate,
                minRewardableAmount,
            );
            await mineBlock();

            expect(await zkpReserveController.releasableAmount()).to.to.eq(
                releasablePerBlock
                    .mul(4)
                    .add(
                        releasablePerBlockFirstUpdate
                            .mul(2)
                            .add(releasablePerBlockSecondUpdate),
                    ),
            );
        });
    });

    describe('Rescue functionality', function () {
        it('should allow owner to rescue ZKP tokens', async function () {
            const rescueAmount = ethers.utils.parseEther('100');
            const ownerAddress = await owner.getAddress();
            const initialBalance = await zkpToken.balanceOf(ownerAddress);

            // Perform the rescue operation
            await expect(
                zkpReserveController
                    .connect(owner)
                    .rescueZkps(ownerAddress, rescueAmount),
            )
                .to.emit(zkpReserveController, 'ZkpRescued')
                .withArgs(ownerAddress, rescueAmount);

            const finalBalance = await zkpToken.balanceOf(ownerAddress);
            expect(finalBalance).to.equal(initialBalance.add(rescueAmount));
        });

        it('should revert when non-owner tries to rescue ZKP tokens', async function () {
            const rescueAmount = ethers.utils.parseEther('50');
            const nonOwnerAddress = await nonOwner.getAddress();

            await expect(
                zkpReserveController
                    .connect(nonOwner)
                    .rescueZkps(nonOwnerAddress, rescueAmount),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });
});
