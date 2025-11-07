// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber, providers} from 'ethers';
import {ethers} from 'hardhat';

import {ClaimTreasury, TokenMock} from '../../types/contracts';

describe('ClaimTreasury', () => {
    let deployer: SignerWithAddress;
    let treasuryOwner: SignerWithAddress;
    let recipient: SignerWithAddress;
    let signerA: SignerWithAddress;
    let signerB: SignerWithAddress;
    let signerC: SignerWithAddress;
    let outsider: SignerWithAddress;

    let zkp: TokenMock;
    let otherToken: TokenMock;
    let treasury: ClaimTreasury;

    const threshold = 2;

    const parseZkp = (value: string) => ethers.utils.parseEther(value);

    async function deployTokens() {
        const tokenFactory = await ethers.getContractFactory('TokenMock');
        zkp = (await tokenFactory.connect(deployer).deploy()) as TokenMock;
        otherToken = (await tokenFactory
            .connect(deployer)
            .deploy()) as TokenMock;
    }

    async function deployTreasury() {
        const factory = await ethers.getContractFactory('ClaimTreasury');
        treasury = (await factory.connect(deployer).deploy()) as ClaimTreasury;
        const signers = [signerA.address, signerB.address, signerC.address];
        await treasury
            .connect(deployer)
            .initialize(treasuryOwner.address, zkp.address, signers, threshold);
    }

    async function fundTreasury(amount: BigNumber) {
        await zkp.connect(deployer).transfer(treasury.address, amount);
    }

    async function extractClaimId(
        tx: providers.TransactionResponse,
    ): Promise<string> {
        const receipt = await tx.wait();
        const event = receipt.events?.find(e => e.event === 'ClaimProposed');
        if (!event || !event.args) {
            throw new Error('ClaimProposed event not found');
        }

        const claimId = event.args.claimId as string;
        return claimId;
    }

    beforeEach(async () => {
        [
            deployer,
            treasuryOwner,
            recipient,
            signerA,
            signerB,
            signerC,
            outsider,
        ] = await ethers.getSigners();

        await deployTokens();
        await deployTreasury();
    });

    after(async () => {
        // Ensure the next test suite (notably PayMaster) observes a predictable base fee
        await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', [
            '0x3b9aca00', // 1 gwei
        ]);
    });

    describe('initialization', () => {
        it('stores configuration and prevents re-initialization', async () => {
            expect(await treasury.owner()).to.equal(treasuryOwner.address);
            expect(await treasury.zkpToken()).to.equal(zkp.address);
            expect(await treasury.threshold()).to.equal(threshold);
            expect(await treasury.signerCount()).to.equal(3);
            expect(await treasury.isSigner(signerA.address)).to.equal(true);

            await expect(
                treasury
                    .connect(deployer)
                    .initialize(
                        treasuryOwner.address,
                        zkp.address,
                        [signerA.address],
                        1,
                    ),
            ).to.be.revertedWith('ClaimTreasury: already initialized');
        });

        it('validates initialization parameters', async () => {
            const freshTreasury = (await (
                await ethers.getContractFactory('ClaimTreasury')
            )
                .connect(deployer)
                .deploy()) as ClaimTreasury;

            await expect(
                freshTreasury.initialize(
                    ethers.constants.AddressZero,
                    zkp.address,
                    [signerA.address],
                    1,
                ),
            ).to.be.revertedWith('ClaimTreasury: zero owner');

            await expect(
                freshTreasury.initialize(
                    treasuryOwner.address,
                    ethers.constants.AddressZero,
                    [signerA.address],
                    1,
                ),
            ).to.be.revertedWith('ClaimTreasury: zero token');

            await expect(
                freshTreasury.initialize(
                    treasuryOwner.address,
                    zkp.address,
                    [signerA.address],
                    0,
                ),
            ).to.be.revertedWith('ClaimTreasury: zero threshold');

            await expect(
                freshTreasury.initialize(
                    treasuryOwner.address,
                    zkp.address,
                    [signerA.address],
                    2,
                ),
            ).to.be.revertedWith('ClaimTreasury: insufficient signers');

            await expect(
                freshTreasury.initialize(
                    treasuryOwner.address,
                    zkp.address,
                    [signerA.address, signerA.address],
                    1,
                ),
            ).to.be.revertedWith('ClaimTreasury: duplicate signer');
        });
    });

    describe('claim workflow', () => {
        const amount = parseZkp('10');

        beforeEach(async () => {
            await fundTreasury(parseZkp('100'));
        });

        it('allows a signer to open a claim and self-approve it once', async () => {
            const tx = await treasury
                .connect(signerA)
                .submitClaim(recipient.address, amount, false);

            const claimId = await extractClaimId(tx);
            const stored = await treasury.claims(claimId);

            expect(stored.to).to.equal(recipient.address);
            expect(stored.amount).to.equal(amount);
            expect(stored.claimAll).to.equal(false);
            expect(stored.approvals).to.equal(1);
            expect(await treasury.approvals(claimId, signerA.address)).to.equal(
                true,
            );

            await expect(
                treasury.connect(signerA).approveClaim(claimId),
            ).to.be.revertedWith('ClaimTreasury: already approved');
        });

        it('rejects invalid claim arguments', async () => {
            await expect(
                treasury
                    .connect(signerA)
                    .submitClaim(ethers.constants.AddressZero, amount, false),
            ).to.be.revertedWith('ClaimTreasury: zero recipient');

            await expect(
                treasury
                    .connect(signerA)
                    .submitClaim(recipient.address, 0, false),
            ).to.be.revertedWith('ClaimTreasury: zero amount');

            await expect(
                treasury
                    .connect(signerA)
                    .submitClaim(recipient.address, amount, true),
            ).to.be.revertedWith('ClaimTreasury: amount with claimAll');
        });

        it('executes payout once approvals reach the threshold', async () => {
            const tx = await treasury
                .connect(signerA)
                .submitClaim(recipient.address, amount, false);
            const claimId = await extractClaimId(tx);

            const recipientBefore = await zkp.balanceOf(recipient.address);

            await expect(treasury.connect(signerB).approveClaim(claimId))
                .to.emit(treasury, 'ClaimExecuted')
                .withArgs(claimId, signerB.address, recipient.address, amount);

            const recipientAfter = await zkp.balanceOf(recipient.address);
            expect(recipientAfter.sub(recipientBefore)).to.equal(amount);

            await expect(
                treasury.connect(signerC).approveClaim(claimId),
            ).to.be.revertedWith('ClaimTreasury: already executed');
        });

        it('allows claimAll requests to drain the balance', async () => {
            const claimAllBal = await zkp.balanceOf(treasury.address);
            const tx = await treasury
                .connect(signerA)
                .submitClaim(recipient.address, 0, true);
            const claimId = await extractClaimId(tx);

            await treasury.connect(signerB).approveClaim(claimId);

            expect(await zkp.balanceOf(recipient.address)).to.equal(
                claimAllBal,
            );
            expect(await zkp.balanceOf(treasury.address)).to.equal(0);
        });

        it('prevents the owner from acting as a signer when not registered', async () => {
            await expect(
                treasury
                    .connect(treasuryOwner)
                    .submitClaim(recipient.address, amount, false),
            ).to.be.revertedWith('ClaimTreasury: unauthorized signer');
        });

        it('restricts claim actions to initialized signers', async () => {
            await expect(
                treasury
                    .connect(outsider)
                    .submitClaim(recipient.address, amount, false),
            ).to.be.revertedWith('ClaimTreasury: unauthorized signer');

            const uninitializedTreasury = (await (
                await ethers.getContractFactory('ClaimTreasury')
            )
                .connect(deployer)
                .deploy()) as ClaimTreasury;

            await expect(
                uninitializedTreasury
                    .connect(signerA)
                    .submitClaim(recipient.address, amount, false),
            ).to.be.revertedWith('ClaimTreasury: not initialized');
        });
    });

    describe('claimOtherErc20', () => {
        const rescueAmount = parseZkp('5');

        beforeEach(async () => {
            await otherToken
                .connect(deployer)
                .transfer(treasury.address, parseZkp('20'));
        });

        it('allows only the owner to rescue non-ZKP tokens', async () => {
            const before = await otherToken.balanceOf(recipient.address);
            await treasury
                .connect(treasuryOwner)
                .claimOtherErc20(
                    otherToken.address,
                    recipient.address,
                    rescueAmount,
                );
            const after = await otherToken.balanceOf(recipient.address);
            expect(after.sub(before)).to.equal(rescueAmount);
        });

        it('blocks unauthorized or ZKP withdrawals', async () => {
            await expect(
                treasury
                    .connect(signerA)
                    .claimOtherErc20(
                        otherToken.address,
                        recipient.address,
                        rescueAmount,
                    ),
            ).to.be.revertedWith('ClaimTreasury: unauthorized owner');

            await expect(
                treasury
                    .connect(treasuryOwner)
                    .claimOtherErc20(
                        zkp.address,
                        recipient.address,
                        rescueAmount,
                    ),
            ).to.be.revertedWith('ClaimTreasury: reserved');
        });
    });
});
