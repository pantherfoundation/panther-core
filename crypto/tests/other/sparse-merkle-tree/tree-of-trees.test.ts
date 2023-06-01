// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2022-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {range} from 'lodash';

import {
    SparseMerkleTree,
    TreeOfTrees,
} from '../../../src/other/sparse-merkle-tree';

const asint = (...values: number[]): bigint[] => values.map(BigInt);

describe('TreeOfTrees', () => {
    describe('tree.getLeaf()', () => {
        const subtree = new SparseMerkleTree(asint(1, 2, 3), 3);
        const tree = new TreeOfTrees([subtree], 3, {depth: 3});
        const zeroTree = new SparseMerkleTree([], 3);

        it('should get the leaf value by leaf id', () => {
            expect(tree.getLeaf(0)).to.be.eq(BigInt(1));
            expect(tree.getLeaf(1)).to.be.eq(BigInt(2));
            expect(tree.getLeaf(2)).to.be.eq(BigInt(3));
            expect(tree.getLeaf(8)).to.be.eq(zeroTree.getLeaf(0));
            expect(tree.getLeaf(17)).to.be.eq(zeroTree.getLeaf(7));
        });

        it('should throw an error for invalid leaf id', () => {
            expect(() => tree.getLeaf(64)).to.throw(
                '[leafIdAsIdx] invalid leaf id',
            );

            expect(() => tree.getLeaf(-1)).to.throw(
                '[leafIdAsIdx] invalid leaf id',
            );
        });
    });

    describe('tree.addLeaf()', () => {
        it('should add leaf to the tree', () => {
            const tree = new TreeOfTrees([], 2, {depth: 2});
            expect(tree.getLeaf(0)).to.be.eq(BigInt(0));
            tree.addLeaf(BigInt(1));
            expect(tree.getLeaf(0)).to.be.eq(BigInt(1));

            expect(tree.getLeaf(1)).to.be.eq(BigInt(0));
            tree.addLeaf(BigInt(2));
            expect(tree.getLeaf(1)).to.be.eq(BigInt(2));
        });

        it('should throw error when the tree is full', () => {
            const tree = new TreeOfTrees([], 2, {depth: 2});
            expect(tree.getLeaf(0)).to.be.eq(BigInt(0));

            const leaves = range(16).map(BigInt);
            leaves.forEach(leaf => tree.addLeaf(leaf));

            expect(() => tree.addLeaf(BigInt(9))).to.throw(
                '[addLeaf] tree overflow. Tree is full.',
            );
        });
    });

    describe('tree.getRoot()', () => {
        it('should get the root of the tree', () => {
            const depth = 3;
            const subtree = new SparseMerkleTree(asint(1, 2, 3), depth);
            const zeroTree = new SparseMerkleTree([], depth);
            const tree = new TreeOfTrees([subtree], 2, {depth});

            expect(tree.getRoot()).to.eq(
                new SparseMerkleTree(
                    [
                        subtree.getRoot(),
                        ...new Array(3).fill(zeroTree.getRoot()),
                    ],
                    2,
                ).getRoot(),
            );
        });
    });

    describe('tree.getProof()', () => {
        it('should generate a proof for non-zero leaf', () => {
            const depth = 3;
            const subtree = new SparseMerkleTree(asint(1, 2, 3), depth);
            const zeroTree = new SparseMerkleTree([], depth);
            const tree = new TreeOfTrees([subtree], 2, {depth});

            const leafId = 3;
            const testProof = tree.getProof(leafId);
            const subtreeProof = subtree.getProof(leafId);

            expect(testProof).to.be.of.length(depth + 2);
            subtreeProof.forEach((leaf, idx) => {
                expect(testProof[idx]).to.be.eq(leaf);
            });
            expect(testProof[3]).to.be.eq(zeroTree.getRoot());
            expect(testProof[4]).to.be.eq(
                poseidon([zeroTree.getRoot(), zeroTree.getRoot()]),
            );
        });

        it('should generate a proof for zero leaf', () => {
            const depth = 2;
            const zeroTree = new SparseMerkleTree([], depth);
            const tree = new TreeOfTrees([], 2, {depth});
            const leafId = 4; // Second tree, first leaf
            const testProof = tree.getProof(leafId);
            const subtreeProof = zeroTree.getProof(0);

            expect(testProof).to.be.of.length(4);
            subtreeProof.forEach((leaf, idx) => {
                expect(testProof[idx]).to.be.eq(leaf);
            });

            const zeroRoot = zeroTree.getRoot();
            expect(testProof[2]).to.be.eq(zeroRoot);
            expect(testProof[3]).to.be.eq(poseidon([zeroRoot, zeroRoot]));
        });

        it('should throw error for invalid leaf id', () => {
            const depth = 2;
            const tree = new TreeOfTrees([], 2, {depth});
            const leafId = 100;

            expect(() => tree.getProof(leafId)).to.throw(
                '[leafIdAsIdx] invalid leaf id',
            );
        });
    });

    describe('tree.verifyProof()', () => {
        let tree: TreeOfTrees;
        let depth: number;

        beforeAll(() => {
            depth = 3;
            const subtree = new SparseMerkleTree(asint(1, 2, 3), depth);
            tree = new TreeOfTrees([subtree], 2, {depth});
        });

        it('should accept honest merkle proof (non-zero leaf)', () => {
            const leafId = 2;
            const proof = tree.getProof(leafId);
            const leaf = tree.getLeaf(leafId);

            expect(leaf).to.be.eq(BigInt(3));
            expect(tree.verifyProof(leaf, leafId, proof)).to.be.true;
        });

        it('should accept honest merkle proof (zero leaf)', () => {
            const zeroTree = new SparseMerkleTree([], depth);

            const leafId = 12;
            const [_, leafIdx] = tree.leafIdAsIdx(leafId);
            const proof = tree.getProof(leafId);
            const leaf = tree.getLeaf(leafId);

            expect(leaf).to.be.eq(zeroTree.getLeaf(leafIdx));
            expect(tree.verifyProof(leaf, leafId, proof)).to.be.true;
        });

        it('should reject dishonest merkle proof', () => {
            const leafId = 2;
            const proof = tree.getProof(leafId);
            const leaf = tree.getLeaf(leafId);

            proof[0] = BigInt(1);
            expect(tree.verifyProof(leaf, leafId, proof)).to.be.false;
        });
    });
});
