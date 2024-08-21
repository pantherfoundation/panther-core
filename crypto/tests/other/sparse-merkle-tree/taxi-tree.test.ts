// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {range} from 'lodash';

import {
    SparseMerkleTree,
    TAXI_SUBTREE_DEPTH,
    TAXI_TREE_DEPTH,
    TREE_ZERO_LEAF,
} from '../../../src/other/sparse-merkle-tree';
import {TaxiTree} from '../../../src/other/sparse-merkle-tree/taxi-tree';

describe('TaxiTree', () => {
    it('should be the same as empty smt of the same depth', () => {
        const test = new SparseMerkleTree(
            [],
            TAXI_TREE_DEPTH,
            BigInt(TREE_ZERO_LEAF),
        );
        const tree = new TaxiTree({left: [], right: []});
        expect(tree.getRoot()).to.be.eq(test.getRoot());
    });

    it('should generate a proof the same as regular smt', () => {
        const left = range(0, 128).map(BigInt);
        const right = range(128, 256).map(BigInt);
        const test = new SparseMerkleTree(
            [...left, ...right],
            TAXI_TREE_DEPTH,
            BigInt(TREE_ZERO_LEAF),
        );
        const tree = new TaxiTree({left, right});
        expect(tree.getRoot()).to.be.eq(test.getRoot());
        expect(tree.getProof(0)).to.be.deep.eq(test.getProof(0));
        expect(tree.getProof(10)).to.be.deep.eq(test.getProof(10));
        expect(tree.getProof(128)).to.be.deep.eq(test.getProof(128));
        expect(tree.getProof(255)).to.be.deep.eq(test.getProof(255));
    });

    it('should work with abstracted subtree roots', () => {
        const left = range(0, 128).map(BigInt);
        const right = range(128, 256).map(BigInt);
        const leftSubtree = new SparseMerkleTree(
            left,
            TAXI_SUBTREE_DEPTH,
            BigInt(TREE_ZERO_LEAF),
        );
        const test = new SparseMerkleTree(
            [...left, ...right],
            TAXI_TREE_DEPTH,
            BigInt(TREE_ZERO_LEAF),
        );
        const tree = new TaxiTree({left: leftSubtree.getRoot(), right});
        expect(tree.getRoot()).to.be.eq(test.getRoot());
        expect(() => tree.getProof(0)).to.throws(
            'Cannot generate proof from abstracted subtree',
        );
        expect(tree.getProof(128)).to.be.deep.eq(test.getProof(128));
        expect(tree.getProof(255)).to.be.deep.eq(test.getProof(255));
    });

    it('should throw errors for invalid leaf index', () => {
        const left = range(0, 128).map(BigInt);
        const right = range(128, 256).map(BigInt);
        const tree = new TaxiTree({left, right});
        expect(() => tree.getProof(-1)).to.throws('Leaf index out of bound');
        expect(() => tree.getProof(256)).to.throws('Leaf index out of bound');
    });

    it('should throw error when trying to generate a proof from abstracted subtree', () => {
        const tree = new TaxiTree({left: 0n, right: 1n});
        expect(() => tree.getProof(127)).to.throws(
            'Cannot generate proof from abstracted subtree',
        );
        expect(() => tree.getProof(255)).to.throws(
            'Cannot generate proof from abstracted subtree',
        );
    });
});
