// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SNARK_FIELD_SIZE} from '@panther-core/crypto/lib/utils/constants';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {revertSnapshot, takeSnapshot} from '../../lib/hardhat';
import {MockBinaryIncrementalUpdatableMerkleTree} from '../../types/contracts';

import {getPoseidonT3Contract} from './../../lib/poseidonBuilder';

describe('Binary Incremental Updatable Merkle Tree', () => {
    let tree: MockBinaryIncrementalUpdatableMerkleTree;
    let snapshot: number;

    before(async () => {
        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        const MockBinaryIncrementalUpdatableMerkleTree =
            await ethers.getContractFactory(
                'MockBinaryIncrementalUpdatableMerkleTree',
                {
                    libraries: {
                        PoseidonT3: poseidonT3.address,
                    },
                },
            );
        tree =
            (await MockBinaryIncrementalUpdatableMerkleTree.deploy()) as MockBinaryIncrementalUpdatableMerkleTree;
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();
    });

    afterEach(async () => {
        await revertSnapshot(snapshot);
    });

    describe('insert', () => {
        const leaf = ethers.BigNumber.from(
            ethers.utils.formatBytes32String('random-leaf'),
        ).mod(SNARK_FIELD_SIZE);

        it('should insert leaf', async () => {
            await tree.internalInsert(leaf);

            expect(await tree.getNextLeafIndex()).to.be.equal(1);
            expect((await tree.internalFilledSubtrees(0))[0]).to.be.equal(leaf);
        });
    });
});
