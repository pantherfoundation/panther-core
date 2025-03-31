// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {expect} from 'chai';

import {
    BusTree,
    FOREST_TREE_DEPTH,
    ForestTree,
    SparseMerkleTree,
} from '../../../src/other/sparse-merkle-tree';

const leaves = [1, 2, 3, 4].map(BigInt);
const taxiTree = new SparseMerkleTree(leaves, 2);
const busTree = new BusTree(0, leaves, [], [], 2, 2, 6);
const ferryTree = taxiTree;
const staticTree = taxiTree;

describe('ForestTree', () => {
    it('Should generate forest tree root from all subtrees', () => {
        const forestTree = new ForestTree(
            taxiTree,
            busTree,
            ferryTree,
            staticTree,
        );

        expect(forestTree.depth).to.eq(FOREST_TREE_DEPTH);
        expect(forestTree.getRoot()).to.eq(
            new SparseMerkleTree(
                [
                    taxiTree.getRoot(),
                    busTree.getRoot(),
                    ferryTree.getRoot(),
                    staticTree.getRoot(),
                ],
                2,
            ).getRoot(),
        );
    });

    it('should accept tree roots', () => {
        const forestTree = new ForestTree(0n, 1n, 2n, 3n);

        expect(forestTree.getRoot().toString()).to.be.eq(
            '3720616653028013822312861221679392249031832781774563366107458835261883914924',
        );
    });

    it('should generate root directly from other trees', () => {
        const forestRoot = ForestTree.getForestRoot(0n, 1n, 2n, 3n);
        expect(forestRoot.toString()).to.be.eq(
            '3720616653028013822312861221679392249031832781774563366107458835261883914924',
        );
    });
});
