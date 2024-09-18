// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

//TODO: enable eslint
/* eslint-disable */

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/lib/utils/constants';
import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {ethers} from 'hardhat';

import {ensureMinBalance, impersonate} from '../../lib/hardhat';
import {getPoseidonT6Contract} from '../../lib/poseidonBuilder';
import {MockStaticTree, MockStaticRootGetter} from '../../types/contracts';

describe('PantherStaticTree', function () {
    let PantherStaticTree;
    let mockStaticRootGetter: MockStaticRootGetter;
    let pantherStaticTree: MockStaticTree;
    let owner: SignerWithAddress;
    let user: SignerWithAddress;

    const zeroIndex = ethers.BigNumber.from(0);
    const oneIndex = ethers.BigNumber.from(1);

    const NEW_LEAF = ethers.BigNumber.from(
        ethers.utils.formatBytes32String('newLeaf'),
    ).mod(SNARK_FIELD_SIZE);
    const zeroRoot =
        '0x0a5e5ec37bd8f9a21a1c2192e7c37d86bf975d947c2b38598b00babe567191c9';
    const NonZeroRoot =
        '0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69';

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        const PoseidonT6 = await getPoseidonT6Contract();
        const poseidonT6 = await PoseidonT6.deploy();
        await poseidonT6.deployed();

        const staticTreeGetter = await ethers.getContractFactory(
            'MockStaticRootGetter',
        );
        mockStaticRootGetter =
            (await staticTreeGetter.deploy()) as MockStaticRootGetter;

        PantherStaticTree = await ethers.getContractFactory('MockStaticTree', {
            libraries: {
                PoseidonT6: poseidonT6.address,
            },
        });

        pantherStaticTree = (await PantherStaticTree.deploy(
            mockStaticRootGetter.address,
        )) as MockStaticTree;

        await pantherStaticTree.deployed();
    });

    describe('Deployment', function () {
        it('Should revert if the self or controller address is zero address', async function () {
            await expect(
                PantherStaticTree.deploy(ethers.constants.AddressZero),
            ).to.be.revertedWith('init: zero address');
        });
    });

    describe('initializeStaticTree', function () {
        it('Should initialize correctly', async function () {
            await pantherStaticTree.connect(owner).initializeStaticTree();
            const root = poseidon([
                zeroRoot,
                zeroRoot,
                zeroRoot,
                zeroRoot,
                NonZeroRoot,
            ]);

            expect(await pantherStaticTree.getStaticRoot()).to.equal(root);
        });

        it('Should show correct leafs', async function () {
            await pantherStaticTree.initializeStaticTree();

            expect(await pantherStaticTree.leafs(0)).to.eq(zeroRoot);
            expect(await pantherStaticTree.leafs(1)).to.eq(zeroRoot);
            expect(await pantherStaticTree.leafs(2)).to.eq(zeroRoot);
            expect(await pantherStaticTree.leafs(3)).to.eq(zeroRoot);
            expect(await pantherStaticTree.leafs(4)).to.eq(NonZeroRoot);
        });

        it('Should not allow random user to initialize', async function () {
            await expect(
                pantherStaticTree.connect(user).initializeStaticTree(),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });

        it('Should revert if the static tree is already initialized', async function () {
            await pantherStaticTree.initializeStaticTree();
            await expect(
                pantherStaticTree.initializeStaticTree(),
            ).to.be.revertedWith('PF: Already initialized');
        });
    });

    describe('updateStaticRoot', function () {
        it('Should update root and emit event', async function () {
            await pantherStaticTree.initializeStaticTree();
            const signer = await impersonate(mockStaticRootGetter.address);
            await ensureMinBalance(
                signer.address,
                ethers.utils.parseEther('10'),
            );

            const newLeafs = [
                NEW_LEAF,
                zeroRoot,
                zeroRoot,
                zeroRoot,
                NonZeroRoot,
            ];

            const newRoot = poseidon(newLeafs);

            await expect(
                await pantherStaticTree
                    .connect(signer)
                    .updateStaticRoot(NEW_LEAF, zeroIndex),
            )
                .to.emit(pantherStaticTree, 'RootUpdated')
                .withArgs(zeroIndex, NEW_LEAF, newRoot);
        });

        it('Should not allow wrong controller to update root', async function () {
            await expect(
                pantherStaticTree
                    .connect(user)
                    .updateStaticRoot(NEW_LEAF, oneIndex),
            ).to.be.revertedWith('unauthorized');
        });

        it('Should revert if the leafIndex is invalid', async function () {
            await expect(
                pantherStaticTree.updateStaticRoot(NEW_LEAF, 7),
            ).to.be.revertedWith('PF: INVALID_LEAF_IND');
        });
    });
});
