// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {TokenMock, Treasury} from '../../types/contracts';

describe('Treasury', () => {
    let deployer: SignerWithAddress;
    let owner: SignerWithAddress;
    let claimer: SignerWithAddress;
    let receiver: SignerWithAddress;
    let outsider: SignerWithAddress;

    let zkp: TokenMock;
    let otherToken: TokenMock;
    let treasury: Treasury;

    const parseZkp = (value: string) => ethers.utils.parseEther(value);

    async function deployTokens() {
        const tokenFactory = await ethers.getContractFactory('TokenMock');
        zkp = (await tokenFactory.connect(deployer).deploy()) as TokenMock;
        otherToken = (await tokenFactory
            .connect(deployer)
            .deploy()) as TokenMock;
    }

    async function deployTreasury() {
        const factory = await ethers.getContractFactory('Treasury');
        treasury = (await factory
            .connect(deployer)
            .deploy(owner.address, zkp.address)) as Treasury;
    }

    async function initializeTreasury() {
        await treasury.connect(owner).initialize(claimer.address);
    }

    async function fundTreasury(amount: string) {
        await zkp
            .connect(deployer)
            .transfer(treasury.address, parseZkp(amount));
    }

    beforeEach(async () => {
        [deployer, owner, claimer, receiver, outsider] =
            await ethers.getSigners();
        await deployTokens();
        await deployTreasury();
    });

    after(async () => {
        // Ensure the next test suite (notably PayMaster) observes a predictable base fee
        await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', [
            '0x3b9aca00', // 1 gwei
        ]);
    });

    describe('initialize', () => {
        it('stores configuration and prevents re-initialization', async () => {
            await initializeTreasury();

            expect(await treasury.claimer()).to.equal(claimer.address);

            await expect(
                treasury.connect(owner).initialize(claimer.address),
            ).to.be.revertedWith('Treasury: already initialized');
        });

        it('validates initialization parameters', async () => {
            await expect(
                treasury
                    .connect(owner)
                    .initialize(ethers.constants.AddressZero),
            ).to.be.revertedWith('Treasury: claimer zero');
        });

        it('restricts initialization to owner', async () => {
            await expect(
                treasury.connect(outsider).initialize(claimer.address),
            ).to.be.revertedWith('Treasury: unauthorized owner');
        });
    });

    describe('updateClaimer', () => {
        beforeEach(async () => {
            await initializeTreasury();
        });

        it('allows the owner to update claimer', async () => {
            await treasury.connect(owner).updateClaimer(receiver.address);
            expect(await treasury.claimer()).to.equal(receiver.address);
        });

        it('rejects zero claimer or unauthorized caller', async () => {
            await expect(
                treasury
                    .connect(owner)
                    .updateClaimer(ethers.constants.AddressZero),
            ).to.be.revertedWith('Treasury: claimer zero');

            await expect(
                treasury.connect(outsider).updateClaimer(receiver.address),
            ).to.be.revertedWith('Treasury: unauthorized owner');
        });
    });

    describe('claim', () => {
        beforeEach(async () => {
            await initializeTreasury();
            await fundTreasury('100');
        });

        it('allows claimer to withdraw tokens to receiver', async () => {
            const amount = parseZkp('10');
            const before = await zkp.balanceOf(receiver.address);

            await expect(
                treasury.connect(claimer).claim(receiver.address, amount),
            )
                .to.emit(treasury, 'ClaimExecuted')
                .withArgs(claimer.address, receiver.address, amount);

            const after = await zkp.balanceOf(receiver.address);
            expect(after.sub(before)).to.equal(amount);
        });

        it('enforces access control and input validation', async () => {
            const amount = parseZkp('10');

            await expect(
                treasury.connect(outsider).claim(receiver.address, amount),
            ).to.be.revertedWith('Treasury: not claimer');

            await expect(
                treasury
                    .connect(claimer)
                    .claim(ethers.constants.AddressZero, amount),
            ).to.be.revertedWith('Treasury: receiver zero');
        });

        it('requires initialization before claiming', async () => {
            const freshTreasury = (await (
                await ethers.getContractFactory('Treasury')
            )
                .connect(deployer)
                .deploy(owner.address, zkp.address)) as Treasury;

            await expect(
                freshTreasury
                    .connect(claimer)
                    .claim(receiver.address, parseZkp('1')),
            ).to.be.revertedWith('Treasury: not initialized');
        });
    });

    describe('claimOtherErc20', () => {
        beforeEach(async () => {
            await initializeTreasury();
            await otherToken
                .connect(deployer)
                .transfer(treasury.address, parseZkp('20'));
        });

        it('allows only owner to rescue non-ZKP tokens', async () => {
            const before = await otherToken.balanceOf(receiver.address);
            await treasury
                .connect(owner)
                .claimOtherErc20(
                    otherToken.address,
                    receiver.address,
                    parseZkp('5'),
                );
            const after = await otherToken.balanceOf(receiver.address);
            expect(after.sub(before)).to.equal(parseZkp('5'));
        });

        it('blocks unauthorized or ZKP withdrawals', async () => {
            await expect(
                treasury
                    .connect(outsider)
                    .claimOtherErc20(
                        otherToken.address,
                        receiver.address,
                        parseZkp('5'),
                    ),
            ).to.be.revertedWith('Treasury: unauthorized owner');

            await expect(
                treasury
                    .connect(owner)
                    .claimOtherErc20(
                        zkp.address,
                        receiver.address,
                        parseZkp('5'),
                    ),
            ).to.be.revertedWith('Treasury: reserved');
        });
    });
});
