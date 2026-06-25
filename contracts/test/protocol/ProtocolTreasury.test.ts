// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {TokenMock, ProtocolTreasury} from '../../types/contracts';

describe('ProtocolTreasury', () => {
    let deployer: SignerWithAddress;
    let owner: SignerWithAddress;
    let claimer: SignerWithAddress;
    let receiver: SignerWithAddress;
    let outsider: SignerWithAddress;

    let zkp: TokenMock;
    let otherToken: TokenMock;
    let treasury: ProtocolTreasury;

    const parseZkp = (value: string) => ethers.utils.parseEther(value);

    async function deployTokens() {
        const tokenFactory = await ethers.getContractFactory('TokenMock');
        zkp = (await tokenFactory.connect(deployer).deploy()) as TokenMock;
        otherToken = (await tokenFactory
            .connect(deployer)
            .deploy()) as TokenMock;
    }

    async function deployTreasury() {
        const factory = await ethers.getContractFactory('ProtocolTreasury');
        treasury = (await factory
            .connect(deployer)
            .deploy(owner.address, zkp.address, claimer.address)) as ProtocolTreasury;
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

    describe('constructor', () => {
        it('stores configuration correctly', async () => {
            expect(await treasury.CLAIMER()).to.equal(claimer.address);
            expect(await treasury.OWNER()).to.equal(owner.address);
            expect(await treasury.ZKP_TOKEN()).to.equal(zkp.address);
        });

        it('validates constructor parameters', async () => {
            const factory = await ethers.getContractFactory('ProtocolTreasury');

            await expect(
                factory
                    .connect(deployer)
                    .deploy(
                        ethers.constants.AddressZero,
                        zkp.address,
                        claimer.address,
                    ),
            ).to.be.revertedWith('ProtocolTreasury: owner zero');

            await expect(
                factory
                    .connect(deployer)
                    .deploy(
                        owner.address,
                        ethers.constants.AddressZero,
                        claimer.address,
                    ),
            ).to.be.revertedWith('ProtocolTreasury: token zero');

            await expect(
                factory
                    .connect(deployer)
                    .deploy(
                        owner.address,
                        zkp.address,
                        ethers.constants.AddressZero,
                    ),
            ).to.be.revertedWith('ProtocolTreasury: claimer zero');
        });
    });

    describe('claim', () => {
        beforeEach(async () => {
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
            ).to.be.revertedWith('ProtocolTreasury: not claimer');

            await expect(
                treasury
                    .connect(claimer)
                    .claim(ethers.constants.AddressZero, amount),
            ).to.be.revertedWith('ProtocolTreasury: receiver zero');
        });
    });

    describe('claimOtherErc20', () => {
        beforeEach(async () => {
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
            ).to.be.revertedWith('ProtocolTreasury: unauthorized owner');

            await expect(
                treasury
                    .connect(owner)
                    .claimOtherErc20(
                        zkp.address,
                        receiver.address,
                        parseZkp('5'),
                    ),
            ).to.be.revertedWith('ProtocolTreasury: reserved');
        });
    });
});
