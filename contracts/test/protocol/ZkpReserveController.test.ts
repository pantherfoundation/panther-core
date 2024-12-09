// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {expect} from 'chai';
import {BigNumber, Contract, Signer} from 'ethers';
import {ethers} from 'hardhat';

import abiZkpToken from './data/abi/ZKPToken.json';

const secret = ethers.utils.formatBytes32String('test');

describe('ZkpReserveController', function () {
    let ZkpReserveController: Contract;
    let owner: Signer, user: Signer, nonOwner: Signer, amm: Signer;
    let zkpToken: Contract, prpVoucherController: FakeContract;

    beforeEach(async function () {
        [owner, user, nonOwner, amm] = await ethers.getSigners();

        const ZKPTokenContract = new ethers.ContractFactory(
            abiZkpToken.abi,
            abiZkpToken.bytecode,
            owner,
        );
        zkpToken = await ZKPTokenContract.deploy(await owner.getAddress());
        await zkpToken.deployed();

        prpVoucherController = await smock.fake('PrpVoucherController');

        const ZkpReserveControllerFactory = await ethers.getContractFactory(
            'ZkpReserveController',
        );
        ZkpReserveController = await ZkpReserveControllerFactory.deploy(
            await owner.getAddress(), // owner
            zkpToken.address,
            prpVoucherController.address,
        );
        await ZkpReserveController.deployed();

        // Mint some tokens to the ZkpReserveController contract
        await zkpToken.mint(
            ZkpReserveController.address,
            ethers.utils.parseEther('1000'),
        );
    });

    describe('Deployment', function () {
        it('should deploy with correct initial settings', async function () {
            expect(await ZkpReserveController.ZKP_TOKEN()).to.equal(
                zkpToken.address,
            );
            expect(await ZkpReserveController.OWNER()).to.equal(
                await owner.getAddress(),
            );
            expect(await ZkpReserveController.PANTHER_POOL()).to.equal(
                prpVoucherController.address,
            );
        });
    });

    describe('Configuration', function () {
        const releasablePerBlock = ethers.utils.parseUnits('20', '12');
        const minRewardableAmount = ethers.utils.parseUnits('200', '12');

        it('should update configuration correctly', async function () {
            await ZkpReserveController.updateParams(
                releasablePerBlock,
                minRewardableAmount,
            );
            const {_releasablePerBlock, _minRewardableAmount} =
                await ZkpReserveController.getRewardStats();

            expect(_releasablePerBlock).to.equal(releasablePerBlock);
            expect(_minRewardableAmount).to.equal(minRewardableAmount);
        });

        it('should revert when non-owner tries to update parameters', async function () {
            await expect(
                ZkpReserveController.connect(nonOwner).updateParams(20, 200),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should emit RewardParamsUpdated event when params are updated', async function () {
            await expect(
                ZkpReserveController.updateParams(
                    releasablePerBlock,
                    minRewardableAmount,
                ),
            )
                .to.emit(ZkpReserveController, 'RewardParamsUpdated')
                .withArgs(releasablePerBlock, minRewardableAmount);
        });
    });

    describe('Refill functionality', function () {
        const releasablePerBlock = ethers.utils.parseUnits('20', '12');
        const minRewardableAmount = ethers.utils.parseUnits('200', '12');

        it('should revert if there is nothing to release', async function () {
            await ZkpReserveController.connect(user)
                .releaseZkps(ethers.utils.formatBytes32String('test'))
                .catch((error: any) => {
                    expect(error.message).to.include('no zkp is available');
                });
        });

        it('should release tokens correctly', async function () {
            const releasableAmount = await calcReleasableAmount();

            await expect(ZkpReserveController.connect(user).releaseZkps(secret))
                .to.emit(ZkpReserveController, 'ZkpReservesReleased')
                .withArgs(secret, releasableAmount);

            const balanceAMM = await zkpToken.balanceOf(await amm.getAddress());
            expect(balanceAMM).to.equal(releasableAmount);
        });

        it('should not reward if released amount is below minimalRewardedAmount', async function () {
            await ZkpReserveController.updateParams(
                releasablePerBlock,
                minRewardableAmount,
            );

            const releasableAmount = await calcReleasableAmount();

            await expect(ZkpReserveController.connect(user).releaseZkps(secret))
                .to.emit(ZkpReserveController, 'ZkpReservesReleased')
                .withArgs(secret, releasableAmount);
        });

        it('should reward if released amount is above minimalRewardedAmount', async function () {
            await ZkpReserveController.updateParams(
                releasablePerBlock,
                minRewardableAmount,
            );

            const releasableAmount = await calcReleasableAmount();
            await expect(ZkpReserveController.connect(user).releaseZkps(secret))
                .to.emit(ZkpReserveController, 'ZkpReservesReleased')
                .withArgs(secret, releasableAmount);
        });

        it('should calculate releasable amount correctly over time', async function () {
            const initialBlock = await ethers.provider.getBlockNumber();
            const params = await ZkpReserveController.getRewardStats();

            const expectedAmount =
                params._releasablePerBlock * initialBlock -
                params._totalReleased;
            expect(await ZkpReserveController.releasableAmount()).to.equal(
                expectedAmount,
            );

            // Simulate advancing blocks
            await ethers.provider.send('evm_mine', []);
            await ethers.provider.send('evm_mine', []);

            const newBlock = await ethers.provider.getBlockNumber();
            const newExpectedAmount =
                params._releasablePerBlock * newBlock - params._totalReleased;
            expect(await ZkpReserveController.releasableAmount()).to.equal(
                newExpectedAmount,
            );
        });

        it('should update balances correctly after refill', async function () {
            const initialBalance = await zkpToken.balanceOf(
                await amm.getAddress(),
            );
            const releasableAmount = await calcReleasableAmount();

            await ZkpReserveController.connect(user).releaseZkps(secret);

            const finalBalance = await zkpToken.balanceOf(
                await amm.getAddress(),
            );
            expect(finalBalance).to.equal(initialBalance.add(releasableAmount));
        });

        it('should emit ZkpReservesReleased event when refilled', async function () {
            const releasableAmount = await calcReleasableAmount();

            await expect(ZkpReserveController.connect(user).releaseZkps(secret))
                .to.emit(ZkpReserveController, 'ZkpReservesReleased')
                .withArgs(secret, releasableAmount);
        });
    });

    describe('Rescue functionality', function () {
        it('should allow owner to rescue ZKP tokens', async function () {
            const rescueAmount = ethers.utils.parseEther('100');
            const ownerAddress = await owner.getAddress();
            const initialBalance = await zkpToken.balanceOf(ownerAddress);

            // Perform the rescue operation
            await expect(
                ZkpReserveController.connect(owner).rescueZkps(
                    ownerAddress,
                    rescueAmount,
                ),
            )
                .to.emit(ZkpReserveController, 'ZkpRescued')
                .withArgs(ownerAddress, rescueAmount);

            const finalBalance = await zkpToken.balanceOf(ownerAddress);
            expect(finalBalance).to.equal(initialBalance.add(rescueAmount));
        });

        it('should revert when non-owner tries to rescue ZKP tokens', async function () {
            const rescueAmount = ethers.utils.parseEther('50');
            const nonOwnerAddress = await nonOwner.getAddress();

            await expect(
                ZkpReserveController.connect(nonOwner).rescueZkps(
                    nonOwnerAddress,
                    rescueAmount,
                ),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    async function calcReleasableAmount() {
        const currBlock = await ethers.provider.getBlockNumber();
        const params = await ZkpReserveController.getRewardStats();

        const blockOffset = BigNumber.from(currBlock)
            .sub(params._startBlock)
            .add(1);

        const releasableAmount = params._releasablePerBlock
            .mul(blockOffset)
            .sub(params._totalReleased);

        return releasableAmount;
    }
});
