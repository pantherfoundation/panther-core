// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {expect} from 'chai';
import {Contract, Signer} from 'ethers';
import {ethers} from 'hardhat';

import abiZkpToken from './data/abi/ZKPToken.json';

describe('AMMRefill', function () {
    let AMMRefill: Contract;
    let owner: Signer, user: Signer, nonOwner: Signer, amm: Signer;
    let zkpToken: Contract, prpVoucherGrantor: FakeContract;
    const secret = ethers.utils.formatBytes32String('test');

    beforeEach(async function () {
        [owner, user, nonOwner, amm] = await ethers.getSigners();

        const ZKPTokenContract = new ethers.ContractFactory(
            abiZkpToken.abi,
            abiZkpToken.bytecode,
            owner,
        );
        zkpToken = await ZKPTokenContract.deploy(await owner.getAddress());
        await zkpToken.deployed();

        prpVoucherGrantor = await smock.fake('PrpVoucherGrantor');

        const AMMRefillFactory = await ethers.getContractFactory('AMMRefill');
        AMMRefill = await AMMRefillFactory.deploy(
            zkpToken.address,
            await amm.getAddress(),
            prpVoucherGrantor.address,
            10, // releasableEveryBlock
            100, // minimalRewardedAmount
            await owner.getAddress(), // owner
        );
        await AMMRefill.deployed();

        // Mint some tokens to the AMMRefill contract
        await zkpToken.mint(AMMRefill.address, ethers.utils.parseEther('1000'));
    });

    describe('Deployment', function () {
        it('should deploy with correct initial settings', async function () {
            expect(await AMMRefill.ZKP_TOKEN()).to.equal(zkpToken.address);
            expect(await AMMRefill.AMM()).to.equal(await amm.getAddress());
            expect(await AMMRefill.PRP_VOUCHER_GRANTOR()).to.equal(
                prpVoucherGrantor.address,
            );
        });
    });

    describe('Configuration', function () {
        it('should update configuration correctly', async function () {
            await AMMRefill.updateParams(20, 200);
            const params = await AMMRefill.params();
            expect(params.releasableEveryBlock).to.equal(20);
            expect(params.minimalRewardableAmount).to.equal(200);
        });

        it('should revert when non-owner tries to update parameters', async function () {
            await expect(
                AMMRefill.connect(nonOwner).updateParams(20, 200),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should emit ParamsUpdated event when params are updated', async function () {
            await expect(AMMRefill.updateParams(30, 300))
                .to.emit(AMMRefill, 'ParamsUpdated')
                .withArgs(30, 300);
        });
    });

    describe('Refill functionality', function () {
        it('should revert if there is nothing to release', async function () {
            await AMMRefill.connect(user)
                .refill(ethers.utils.formatBytes32String('test'))
                .catch((error: any) => {
                    expect(error.message).to.include('AR:E2');
                });
        });

        it('should release tokens correctly', async function () {
            const releasableAmount = await calcReleasableAmount();

            await expect(AMMRefill.connect(user).refill(secret))
                .to.emit(AMMRefill, 'Refilled')
                .withArgs(secret, releasableAmount, 0);

            const balanceAMM = await zkpToken.balanceOf(await amm.getAddress());
            expect(balanceAMM).to.equal(releasableAmount);
        });

        it('should not reward if released amount is below minimalRewardedAmount', async function () {
            await AMMRefill.updateParams(10, 200);

            const releasableAmount = await calcReleasableAmount();
            await expect(AMMRefill.connect(user).refill(secret))
                .to.emit(AMMRefill, 'Refilled')
                .withArgs(secret, releasableAmount, 0);
        });

        it('should reward if released amount is above minimalRewardedAmount', async function () {
            await AMMRefill.updateParams(10, 5);

            const releasableAmount = await calcReleasableAmount();
            await expect(AMMRefill.connect(user).refill(secret))
                .to.emit(AMMRefill, 'Refilled')
                .withArgs(secret, releasableAmount, releasableAmount);
        });

        it('should calculate releasable amount correctly over time', async function () {
            const initialBlock = await ethers.provider.getBlockNumber();
            const params = await AMMRefill.params();

            const expectedAmount =
                params.releasableEveryBlock * initialBlock - params.offset;
            expect(await AMMRefill.releasableAmount()).to.equal(expectedAmount);

            // Simulate advancing blocks
            await ethers.provider.send('evm_mine', []);
            await ethers.provider.send('evm_mine', []);

            const newBlock = await ethers.provider.getBlockNumber();
            const newExpectedAmount =
                params.releasableEveryBlock * newBlock - params.offset;
            expect(await AMMRefill.releasableAmount()).to.equal(
                newExpectedAmount,
            );
        });

        it('should update balances correctly after refill', async function () {
            const initialBalance = await zkpToken.balanceOf(
                await amm.getAddress(),
            );
            const releasableAmount = await calcReleasableAmount();

            await AMMRefill.connect(user).refill(secret);

            const finalBalance = await zkpToken.balanceOf(
                await amm.getAddress(),
            );
            expect(finalBalance).to.equal(initialBalance.add(releasableAmount));
        });

        it('should emit Refilled event when refilled', async function () {
            const releasableAmount = await calcReleasableAmount();

            await expect(AMMRefill.connect(user).refill(secret))
                .to.emit(AMMRefill, 'Refilled')
                .withArgs(secret, releasableAmount, 0);
        });
    });

    async function calcReleasableAmount() {
        const currBlock = await ethers.provider.getBlockNumber();
        const params = await AMMRefill.params();

        const releasableAmount =
            params.releasableEveryBlock * (currBlock + 1) - params.offset;
        return releasableAmount;
    }
});
