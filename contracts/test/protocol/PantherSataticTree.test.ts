// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {smock} from '@defi-wonderland/smock';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/lib/utils/constants';
import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {ethers} from 'hardhat';

import {getPoseidonT6Contract} from '../../lib/poseidonBuilder';

import {BYTES32_ZERO} from './shared';

describe.skip('PantherStaticTree', function () {
    let PantherStaticTree;
    let staticTreeImpl;
    let pantherStaticTree: PantherStaticTree;
    let owner;
    let user;
    let _zAssetsTreeController;
    let _zAccountsBlacklistedTreeController;
    let _zNetworksTreeController;
    let _zZnonesTreeController;
    let _providersKeysTreeController;

    const zeroIndex = ethers.BigNumber.from(0);
    const oneIndex = ethers.BigNumber.from(1);
    const HARDCODED_LEAF = ethers.BigNumber.from(
        ethers.utils.formatBytes32String('random-leaf'),
    ).mod(SNARK_FIELD_SIZE);

    const NEW_LEAF = ethers.BigNumber.from(
        ethers.utils.formatBytes32String('newLeaf'),
    ).mod(SNARK_FIELD_SIZE);

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        const EIP173Proxy = await ethers.getContractFactory('EIP173Proxy');

        const staticTreeProxy = await EIP173Proxy.deploy(
            ethers.constants.AddressZero, // implementation will be changed
            owner.address,
            [],
        );

        const PoseidonT6 = await getPoseidonT6Contract();
        const poseidonT6 = await PoseidonT6.deploy();
        await poseidonT6.deployed();

        PantherStaticTree = await ethers.getContractFactory(
            'PantherStaticTree',
            {
                libraries: {
                    PoseidonT6: poseidonT6.address,
                },
            },
        );

        const MockTreeRootGetterAndUpdater = await ethers.getContractFactory(
            'MockTreeRootGetterAndUpdater',
        );

        _zAssetsTreeController = await MockTreeRootGetterAndUpdater.deploy(
            staticTreeProxy.address,
        );

        _zAccountsBlacklistedTreeController =
            await smock.fake('ZAccountsRegistry');
        _zNetworksTreeController = await smock.fake('ITreeRootGetter');
        _zZnonesTreeController = await smock.fake('ITreeRootGetter');
        _providersKeysTreeController = await smock.fake('ITreeRootGetter');

        _zAccountsBlacklistedTreeController.getRoot.returns(HARDCODED_LEAF);
        _zNetworksTreeController.getRoot.returns(HARDCODED_LEAF);
        _zZnonesTreeController.getRoot.returns(HARDCODED_LEAF);
        _providersKeysTreeController.getRoot.returns(HARDCODED_LEAF);

        staticTreeImpl = await PantherStaticTree.deploy(
            owner.address,
            _zAssetsTreeController.address,
            _zAccountsBlacklistedTreeController.address,
            _zNetworksTreeController.address,
            _zZnonesTreeController.address,
            _providersKeysTreeController.address,
        );

        await staticTreeImpl.deployed();

        await staticTreeProxy.upgradeTo(staticTreeImpl.address);
        pantherStaticTree = PantherStaticTree.attach(staticTreeProxy.address);
    });

    it('Should set the right owner', async function () {
        expect(await pantherStaticTree.OWNER()).to.equal(owner.address);
    });

    it('Should set the right controllers', async function () {
        expect(await pantherStaticTree.ZASSETS_TREE_CONTROLLER()).to.equal(
            _zAssetsTreeController.address,
        );
        expect(
            await pantherStaticTree.ZACCOUNTS_BLACKLISTED_TREE_CONTROLLER(),
        ).to.equal(_zAccountsBlacklistedTreeController.address);
        expect(await pantherStaticTree.ZNETWORKS_TREE_CONTROLLER()).to.equal(
            _zNetworksTreeController.address,
        );
        expect(await pantherStaticTree.ZZONES_TREE_CONTROLLER()).to.equal(
            _zZnonesTreeController.address,
        );
        expect(
            await pantherStaticTree.PROVIDERS_KEYS_TREE_CONTROLLER(),
        ).to.equal(_providersKeysTreeController.address);
    });

    it('Should not allow random user to initialize', async function () {
        await expect(
            pantherStaticTree.connect(user).initialize(),
        ).to.be.revertedWith('ImmOwn: unauthorized');
    });

    it('Should initialize correctly', async function () {
        await pantherStaticTree.initialize();
        const root = poseidon([
            BYTES32_ZERO,
            HARDCODED_LEAF,
            HARDCODED_LEAF,
            HARDCODED_LEAF,
            HARDCODED_LEAF,
        ]);
        // Check if the static tree root or other initial state is correct
        expect(await pantherStaticTree.getRoot()).to.equal(root);
    });

    it('Should show correct leafs', async function () {
        await pantherStaticTree.initialize();
        expect(await pantherStaticTree.leafs(0)).to.eq(BYTES32_ZERO);
        expect(await pantherStaticTree.leafs(1)).to.eq(HARDCODED_LEAF);
        expect(await pantherStaticTree.leafs(2)).to.eq(HARDCODED_LEAF);
        expect(await pantherStaticTree.leafs(3)).to.eq(HARDCODED_LEAF);
        expect(await pantherStaticTree.leafs(4)).to.eq(HARDCODED_LEAF);
    });

    it('Should not allow EOA to update root', async function () {
        await expect(
            pantherStaticTree.connect(user).updateRoot(NEW_LEAF, zeroIndex),
        ).to.be.revertedWith('unauthorized');
    });

    it('Should not allow wrong controller to update root', async function () {
        await expect(
            pantherStaticTree.connect(user).updateRoot(NEW_LEAF, oneIndex),
        ).to.be.revertedWith('unauthorized');
    });

    it('Should update root and emit event', async function () {
        await pantherStaticTree.initialize();

        const newLeafs = [
            NEW_LEAF,
            HARDCODED_LEAF,
            HARDCODED_LEAF,
            HARDCODED_LEAF,
            HARDCODED_LEAF,
        ];

        const newRoot = poseidon(newLeafs);

        await expect(
            await _zAssetsTreeController.updateRoot(NEW_LEAF, zeroIndex),
        )
            .to.emit(pantherStaticTree, 'RootUpdated')
            .withArgs(
                zeroIndex,
                NEW_LEAF,
                newRoot,
                // await pantherStaticTree.getRoot(),
            );
    });

    it('Should return the correct static tree root', async function () {
        const root = await pantherStaticTree.getRoot();
        expect(root).to.be.a('string');
    });
});
