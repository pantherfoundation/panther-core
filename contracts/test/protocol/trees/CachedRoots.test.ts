// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {ethers} from 'hardhat';

import {getPoseidonT4Contract} from '../../../lib/poseidonBuilder';
import {MockCachedRoots} from '../../../types/contracts';
import {randomInputGenerator} from '../helpers/randomSnarkFriendlyInputGenerator';

describe('RingBufferRootCache', function () {
    let cachedRoots: MockCachedRoots;

    beforeEach(async function () {
        const PoseidonT4 = await getPoseidonT4Contract();
        const poseidonT4 = await PoseidonT4.deploy();
        await poseidonT4.deployed();

        const CachedRoots = await ethers.getContractFactory('MockCachedRoots', {
            libraries: {
                PoseidonT4: poseidonT4.address,
            },
        });

        cachedRoots = await CachedRoots.deploy();
    });

    it('should return no roots cached if nothing is cached yet', async function () {
        await expect(cachedRoots.getCacheStats()).to.be.revertedWith('CR:E1');
    });

    it('should add a new root to the cache', async function () {
        const firstLeaf = randomInputGenerator();
        const secondLeaf = await cachedRoots.forestLeafs(1);
        const thirdLeaf = await cachedRoots.forestLeafs(2);

        const leafIndex = 0;
        const cacheIndex = 0;

        const forestRoot = poseidon([firstLeaf, secondLeaf, thirdLeaf]);

        await expect(
            cachedRoots.internalCacheNewForestRoot(firstLeaf, leafIndex),
        )
            .to.emit(cachedRoots, 'ForestRootUpdated')
            .withArgs(leafIndex, firstLeaf, forestRoot, cacheIndex);

        const cacheStats = await cachedRoots.getCacheStats();
        const isCached = await cachedRoots.isCachedRoot(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(forestRoot), 32),
            0xffff,
        );
        const isCachedWithDefinedIndex = await cachedRoots.isCachedRoot(
            ethers.utils.hexZeroPad(ethers.utils.hexlify(forestRoot), 32),
            cacheIndex,
        );

        expect(cacheStats.numRootsCached).to.equal(1);
        expect(isCachedWithDefinedIndex).to.be.true;
        expect(isCached).to.be.true;
    });

    it('should revert if root is not cached and undefined cache index', async function () {
        const undefinedCacheIndex = await cachedRoots.UNDEFINED_CACHE_INDEX();
        const isCached = await cachedRoots.isCachedRoot(
            ethers.utils.formatBytes32String('notCachedRoot'),
            undefinedCacheIndex,
        );
        expect(isCached).to.be.false;
    });

    it('should revert when checking root with out-of-range cache index', async function () {
        const newRoot = randomInputGenerator();
        await cachedRoots.internalCacheNewForestRoot(newRoot, 0);

        await expect(cachedRoots.isCachedRoot(newRoot, 2)).to.be.revertedWith(
            'CR:E2',
        );
    });
});
