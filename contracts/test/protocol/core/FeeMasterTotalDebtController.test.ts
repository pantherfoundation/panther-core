// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock, FakeContract} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {revertSnapshot, takeSnapshot} from '../../../lib/hardhat';
import {
    TokenMock,
    VaultV1,
    MockFeeMasterTotalDebtController,
} from '../../../types/contracts';

describe('FeeMasterTotalDebtController', function () {
    let feeMasterTotalDebtController: MockFeeMasterTotalDebtController;

    let zkp: TokenMock;
    let vault: FakeContract<VaultV1>;
    let feeMaster: SignerWithAddress;
    let owner: SignerWithAddress;
    let user: SignerWithAddress;

    let snapshotId: number;

    before(async () => {
        [, owner, user, feeMaster] = await ethers.getSigners();

        zkp = await (
            await ethers.getContractFactory('TokenMock', owner)
        ).deploy();

        vault = await smock.fake('VaultV1');
    });

    beforeEach(async function () {
        snapshotId = await takeSnapshot();

        // Deploy FeeMaster Total Debt Controller
        const FeeMasterTotalDebtController = await ethers.getContractFactory(
            'MockFeeMasterTotalDebtController',
        );

        feeMasterTotalDebtController =
            await FeeMasterTotalDebtController.connect(owner).deploy(
                vault.address,
                feeMaster.address,
            );

        await feeMasterTotalDebtController.deployed();
    });

    afterEach(async () => {
        await revertSnapshot(snapshotId);
    });

    describe('#deployment', () => {
        it('should deploy the contract with correct addresses', async function () {
            expect(await feeMasterTotalDebtController.getVaultAddr()).to.equal(
                vault.address,
            );
            expect(
                await feeMasterTotalDebtController.getFeeMasterAddr(),
            ).to.equal(feeMaster.address);
        });
    });

    describe('#getFeeMasterDebt', () => {
        it('should get the debt of the token', async function () {
            await feeMasterTotalDebtController.setFeeMasterDebt(
                zkp.address,
                ethers.BigNumber.from('1000'),
            );
            expect(
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    zkp.address,
                ),
            ).to.equal(ethers.BigNumber.from('1000'));
        });
    });

    describe('#adjustVaultAssetsAndUpdateTotalFeeMasterDebt', () => {
        it('should lock the asset if amount is greater than 0', async function () {
            expect(
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    zkp.address,
                ),
            ).to.equal(0);

            await feeMasterTotalDebtController
                .connect(feeMaster)
                .adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
                    zkp.address,
                    ethers.BigNumber.from('1000'),
                    feeMaster.address,
                );
            expect(
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    zkp.address,
                ),
            ).to.equal(ethers.BigNumber.from('1000'));
            const expectedLockData = {
                tokenType: 0,
                token: zkp.address,
                tokenId: BigNumber.from('0'),
                extAccount: feeMaster.address,
                extAmount: ethers.BigNumber.from('1000'),
            };

            expect(vault.lockAsset).to.have.been.calledOnceWith(
                expectedLockData,
            );
        });

        it('should lock the asset for native token', async function () {
            expect(
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    ethers.constants.AddressZero,
                ),
            ).to.equal(0);

            await feeMasterTotalDebtController
                .connect(feeMaster)
                .adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
                    ethers.constants.AddressZero,
                    ethers.BigNumber.from('1000'),
                    feeMaster.address,
                );
            expect(
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    ethers.constants.AddressZero,
                ),
            ).to.equal(ethers.BigNumber.from('1000'));
            const expectedLockData = {
                tokenType: 255,
                token: ethers.constants.AddressZero,
                tokenId: BigNumber.from('0'),
                extAccount: feeMaster.address,
                extAmount: ethers.BigNumber.from('1000'),
            };

            expect(vault.lockAsset).to.have.been.calledWith(expectedLockData);
        });

        it('should unlock the asset if amount is lesser than 0', async function () {
            await feeMasterTotalDebtController.setFeeMasterDebt(
                zkp.address,
                ethers.BigNumber.from('1000'),
            );

            const feemasterDebt =
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    zkp.address,
                );

            await feeMasterTotalDebtController
                .connect(feeMaster)
                .adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
                    zkp.address,
                    ethers.BigNumber.from('-10'),
                    feeMaster.address,
                );
            expect(
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    zkp.address,
                ),
            ).to.equal(feemasterDebt.sub(ethers.BigNumber.from('10')));
            const expectedLockData = {
                tokenType: 0,
                token: zkp.address,
                tokenId: BigNumber.from('0'),
                extAccount: feeMaster.address,
                extAmount: ethers.BigNumber.from('10'),
            };

            expect(vault.unlockAsset).to.have.been.calledWith(expectedLockData);
        });

        it('should unlock the asset for native token', async function () {
            await feeMasterTotalDebtController.setFeeMasterDebt(
                ethers.constants.AddressZero,
                ethers.BigNumber.from('1000'),
            );

            const feemasterDebt =
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    ethers.constants.AddressZero,
                );

            await feeMasterTotalDebtController
                .connect(feeMaster)
                .adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
                    ethers.constants.AddressZero,
                    ethers.BigNumber.from('-10'),
                    feeMaster.address,
                );
            expect(
                await feeMasterTotalDebtController.getFeeMasterDebt(
                    ethers.constants.AddressZero,
                ),
            ).to.equal(feemasterDebt.sub(ethers.BigNumber.from('10')));

            const expectedLockData = {
                tokenType: 255,
                token: ethers.constants.AddressZero,
                tokenId: BigNumber.from('0'),
                extAccount: feeMaster.address,
                extAmount: ethers.BigNumber.from('10'),
            };

            expect(vault.unlockAsset).to.have.been.calledWith(expectedLockData);
        });

        it('should revert if the caller is not feeMaster', async function () {
            await expect(
                feeMasterTotalDebtController.adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
                    zkp.address,
                    ethers.BigNumber.from('1000'),
                    user.address,
                ),
            ).to.be.revertedWith('unauthorized');
        });
    });
});
