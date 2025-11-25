// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import chai, {expect} from 'chai';
import {ethers, network} from 'hardhat';

import {
    ComplianceTreasury,
    IDebtSettlement,
    TokenMock,
} from '../../types/contracts';

chai.use(smock.matchers);

describe('ComplianceTreasury contract', function () {
    const STABLE_BASE_FEE = '0x3b9aca00'; // 1 gwei
    let owner: SignerWithAddress;
    let trustProvider: SignerWithAddress;
    let receiver: SignerWithAddress;
    let outsider: SignerWithAddress;
    let zkpToken: TokenMock;
    let complianceTreasury: ComplianceTreasury;
    let feeMaster: FakeContract<IDebtSettlement>;
    let snapshotId: string;

    beforeEach(async function () {
        [owner, trustProvider, receiver, outsider] = await ethers.getSigners();

        zkpToken = (await (
            await ethers.getContractFactory('TokenMock', owner)
        ).deploy()) as TokenMock;
        await zkpToken.deployed();

        const ComplianceTreasuryFactory =
            await ethers.getContractFactory('ComplianceTreasury');
        complianceTreasury = (await ComplianceTreasuryFactory.connect(
            owner,
        ).deploy(owner.address, zkpToken.address)) as ComplianceTreasury;
        await complianceTreasury.deployed();

        feeMaster = await smock.fake<IDebtSettlement>('IDebtSettlement');

        await network.provider.send('hardhat_setNextBlockBaseFeePerGas', [
            STABLE_BASE_FEE,
        ]);

        snapshotId = await network.provider.send('evm_snapshot');
    });

    afterEach(async function () {
        if (snapshotId) {
            await network.provider.send('evm_revert', [snapshotId]);
        }
        await network.provider.send('hardhat_setNextBlockBaseFeePerGas', [
            STABLE_BASE_FEE,
        ]);
    });

    describe('#updateTrustProvider', () => {
        it('sets the trust provider by owner', async () => {
            await expect(
                complianceTreasury
                    .connect(owner)
                    .updateTrustProvider(trustProvider.address),
            )
                .to.emit(complianceTreasury, 'TrustProviderUpdated')
                .withArgs(trustProvider.address);

            expect(await complianceTreasury.trustProvider()).to.equal(
                trustProvider.address,
            );
        });

        it('reverts when updated by non-owner', async () => {
            await expect(
                complianceTreasury
                    .connect(trustProvider)
                    .updateTrustProvider(trustProvider.address),
            ).to.be.revertedWith('ComplianceTreasury: unauthorized');
        });

        it('reverts when new trust provider is zero address', async () => {
            await expect(
                complianceTreasury
                    .connect(owner)
                    .updateTrustProvider(ethers.constants.AddressZero),
            ).to.be.revertedWith('ComplianceTreasury: provider zero');
        });
    });

    describe('#claim', () => {
        const claimAmount = ethers.utils.parseEther('1');

        beforeEach(async () => {
            await complianceTreasury
                .connect(owner)
                .updateTrustProvider(trustProvider.address);
        });

        it('reverts when caller is not the active trust provider', async () => {
            await expect(
                complianceTreasury
                    .connect(outsider)
                    .claim(feeMaster.address, receiver.address, claimAmount),
            ).to.be.revertedWith('ComplianceTreasury: not provider');
        });

        it('reverts when feeMaster address is zero', async () => {
            await expect(
                complianceTreasury
                    .connect(trustProvider)
                    .claim(
                        ethers.constants.AddressZero,
                        receiver.address,
                        claimAmount,
                    ),
            ).to.be.revertedWith('ComplianceTreasury: feeMaster zero');
        });

        it('reverts when receiver address is zero', async () => {
            await expect(
                complianceTreasury
                    .connect(trustProvider)
                    .claim(
                        feeMaster.address,
                        ethers.constants.AddressZero,
                        claimAmount,
                    ),
            ).to.be.revertedWith('ComplianceTreasury: receiver zero');
        });

        it('claims debts from FeeMaster via the trust provider', async () => {
            feeMaster['payOff(address,address,uint256)']
                .whenCalledWith(zkpToken.address, receiver.address, claimAmount)
                .returns(claimAmount);

            await expect(
                complianceTreasury
                    .connect(trustProvider)
                    .claim(feeMaster.address, receiver.address, claimAmount),
            )
                .to.emit(complianceTreasury, 'FeesClaimed')
                .withArgs(feeMaster.address, receiver.address, claimAmount);

            expect(
                feeMaster['payOff(address,address,uint256)'],
            ).to.have.been.calledOnceWith(
                zkpToken.address,
                receiver.address,
                claimAmount,
            );
        });
    });
});
