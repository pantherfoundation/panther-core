// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {revertSnapshot, takeSnapshot} from '../../../lib/hardhat';
import {MockAppConfiguration} from '../../../types/contracts';

describe('AppCongifuration', function () {
    let appConfiguration: MockAppConfiguration;
    let owner: SignerWithAddress;
    let user: SignerWithAddress;
    let snapshotId: number;

    before(async () => {
        [, owner, user] = await ethers.getSigners();
    });

    beforeEach(async function () {
        snapshotId = await takeSnapshot();

        const AppConfiguration = await ethers.getContractFactory(
            'MockAppConfiguration',
        );

        appConfiguration = (await AppConfiguration.connect(
            owner,
        ).deploy()) as MockAppConfiguration;

        await appConfiguration.deployed();
    });

    afterEach(async () => {
        await revertSnapshot(snapshotId);
    });

    describe('#deployment', () => {
        it('should set the correct owner addresses', async function () {
            expect(await appConfiguration.owner()).to.equal(owner.address);
        });
    });

    describe('#updateCircuitId', () => {
        it('should update the CircuitId', async function () {
            const CircuitId = 255;
            const txnType = 0;
            await appConfiguration.updateCircuitId(txnType, CircuitId);
            expect(await appConfiguration.getCircuitIds(txnType)).to.equal(
                CircuitId,
            );
        });

        it('should revert if the circuit id is zero', async function () {
            await expect(
                appConfiguration.updateCircuitId(0, 0),
            ).to.be.revertedWith('Zero circuit id');
        });

        it('should revert if the caller is not owner', async function () {
            await expect(
                appConfiguration.connect(user).updateCircuitId(0, 255),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('#updateMaxBlockTimeOffset', () => {
        it('should update MaxBlockTimeOffset', async function () {
            const timeOffset = 100;
            await appConfiguration.updateMaxBlockTimeOffset(timeOffset);
            expect(await appConfiguration.getMaxBlockTimeOffset()).to.equal(
                timeOffset,
            );
        });

        it('should revert if the maxBlockTimeOffset is greater than 60 mins', async function () {
            await expect(
                appConfiguration.updateMaxBlockTimeOffset(3650),
            ).to.be.revertedWith('Too high block time offset');
        });

        it('should revert if the caller is not owner', async function () {
            await expect(
                appConfiguration.connect(user).updateMaxBlockTimeOffset(100),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('#spendNullifier', () => {
        it('should return blocknumber if a Nullifier is spent', async function () {
            const nullifier = ethers.utils.randomBytes(32);
            await appConfiguration.spendNullifier(nullifier);
            expect(
                await appConfiguration.getIsSpent(nullifier),
            ).to.be.not.equal(0);
        });

        it('should return 0 if the Nullifier is not spent', async function () {
            expect(
                await appConfiguration.getIsSpent(ethers.utils.randomBytes(32)),
            ).to.be.equal(0);
        });
    });
});
