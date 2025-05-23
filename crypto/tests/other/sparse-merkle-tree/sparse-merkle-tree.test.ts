// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {range} from 'lodash';
import {MerkleTree} from 'merkletreejs';

import {SparseMerkleTree} from '../../../src/other/sparse-merkle-tree';
import {
    bigIntToBuffer,
    bufferToBigInt,
} from '../../../src/utils/bigint-conversions';

const hash = (layer: bigint[]) => (indexes: number[]) =>
    poseidon(indexes.map(idx => layer[idx]));

class HonestMekleTree extends MerkleTree {
    constructor(leaves: bigint[], zeroValue: bigint, leafCount: number) {
        const asBuffer = HonestMekleTree.asRingBuffer(
            leaves,
            zeroValue,
            leafCount,
        ).map(leaf => bigIntToBuffer(leaf));
        super(
            asBuffer,
            (inputs: Buffer[]): Buffer =>
                bigIntToBuffer(poseidon(inputs.map(bufferToBigInt))),
            {
                concatenator: hashes => hashes,
            },
        );
    }

    static asRingBuffer(
        leaves: bigint[],
        zeroValue: bigint,
        leafCount: number,
    ): bigint[] {
        const numOfLeaves = leaves.length;

        if (numOfLeaves < leafCount)
            return [
                ...leaves,
                ...new Array(leafCount - leaves.length).fill(zeroValue),
            ];

        if (numOfLeaves > leafCount) return leaves.slice(-leafCount);

        return leaves;
    }
}

describe('SparseMerkleTree', () => {
    let leaves: bigint[];
    let honestTree: HonestMekleTree;
    let testTree: SparseMerkleTree;

    beforeAll(() => {
        leaves = range(10).map(leaf => poseidon([BigInt(leaf)]));
        const zeroValue = BigInt(0);
        const zeroValueHash = poseidon([zeroValue]);
        const depth = 10;

        honestTree = new HonestMekleTree(
            leaves,
            zeroValueHash,
            Math.pow(2, depth), // 1024 leaves
        );
        testTree = new SparseMerkleTree(leaves, depth, zeroValueHash);
    });

    describe('constructor()', () => {
        it('should match tree generated by merkletreejs', () => {
            const leaves = [1, 2, 3, 4].map(leaf => poseidon([BigInt(leaf)]));
            const zeroValue = BigInt(0);
            const zeroValueHash = poseidon([zeroValue]);
            const depth = 3;

            const honestTree = new HonestMekleTree(
                leaves,
                zeroValueHash,
                Math.pow(2, depth), // 8 leaves
            );
            const testTree = new SparseMerkleTree(leaves, depth, zeroValueHash);
            expect(testTree.getRoot()).to.be.eq(
                bufferToBigInt(honestTree.getRoot()),
            );
        });

        it('should throw error for invalid number of leaves', () => {
            const leaves = range(20).map(leaf => poseidon([BigInt(leaf)]));
            expect(() => {
                new SparseMerkleTree(leaves, 3);
            }).to.throw(
                '[SparseMerkleTree] tree overflow. Got "20" leaves. Expected to be less than 8',
            );
        });
    });

    describe('tree.getLeaf()', () => {
        it('should get leaf by index', () => {
            const leafIdx = 10;
            expect(testTree.getLeaf(leafIdx)).to.be.eq(
                bufferToBigInt(honestTree.getLeaf(leafIdx)),
            );
        });

        it('should return zero-value when accessing not yet populated leaf', () => {
            const leafIdx = 1_000;
            const leaf = testTree.getLeaf(leafIdx);
            expect(leaf).to.be.eq(bufferToBigInt(honestTree.getLeaf(leafIdx)));
            expect(leaf).to.be.eq(poseidon([BigInt(0)]));
        });

        it('should throw error of invlaid leaf index/id', () => {
            expect(() => {
                testTree.getLeaf(2_000);
            }).to.throw('[getLeaf] invalid leaf index');
        });
    });

    describe('tree.addLeaf()', () => {
        it('should add new leaf to the tree', () => {
            const shouldHash = true;
            const tree = new SparseMerkleTree([], 10, BigInt(0), shouldHash);
            range(10).forEach(leaf => tree.addLeaf(BigInt(leaf), shouldHash));

            const root = tree.getRoot();
            expect(root).to.be.eq(testTree.getRoot());
            expect(root).to.be.eq(bufferToBigInt(honestTree.getRoot()));
        });

        it('should throw error if tree is full', () => {
            const shouldHash = true;
            const tree = new SparseMerkleTree(
                range(4).map(BigInt),
                2,
                BigInt(0),
                shouldHash,
            );

            expect(() => {
                tree.addLeaf(BigInt(42), shouldHash);
            }).to.throw('[addLeaf] tree is full');
        });
    });

    describe('tree.updateLeaf', () => {
        it('should update leaf by index', () => {
            const shouldHash = true;
            const leaves = range(10).map(BigInt);
            const leafIdx = 3;
            leaves[leafIdx] = BigInt(42);
            const tree = new SparseMerkleTree(
                leaves,
                10,
                BigInt(0),
                shouldHash,
            );

            const root = tree.getRoot();
            expect(root).not.to.be.eq(testTree.getRoot());
            expect(root).not.to.be.eq(bufferToBigInt(honestTree.getRoot()));

            tree.updateLeaf(leafIdx, BigInt(3), shouldHash);

            const newRoot = tree.getRoot();
            expect(newRoot).to.be.eq(testTree.getRoot());
            expect(newRoot).to.be.eq(bufferToBigInt(honestTree.getRoot()));
        });

        it('should throw error when updading zero-valued leaf', () => {
            const shouldHash = true;
            const leaves = range(10).map(BigInt);
            const tree = new SparseMerkleTree(
                leaves,
                10,
                BigInt(0),
                shouldHash,
            );

            expect(() => {
                tree.updateLeaf(11, BigInt(12));
            }).to.throw(
                '[updateLeaf] invalid leaf index. should never update zero-valued leaf',
            );
        });
    });

    describe('tree.removeLeaf()', () => {
        it('should remove leaf by index', () => {
            const shouldHash = true;
            const leaves = range(10).map(BigInt);

            const tree = new SparseMerkleTree(
                [BigInt(-1)].concat(leaves),
                10,
                BigInt(0),
                shouldHash,
            );

            const root = tree.getRoot();
            expect(root).not.to.be.eq(testTree.getRoot());
            expect(root).not.to.be.eq(bufferToBigInt(honestTree.getRoot()));

            tree.removeLeaf(0);

            const newRoot = tree.getRoot();
            expect(newRoot).to.be.eq(testTree.getRoot());
            expect(newRoot).to.be.eq(bufferToBigInt(honestTree.getRoot()));
        });

        it('should throw error for invalid index', () => {
            const tree = new SparseMerkleTree(range(4).map(BigInt), 10);
            expect(() => tree.removeLeaf(1_000)).to.throw(
                '[removeLeaf] invalid leaf index. should never remove zero leaf',
            );
        });
    });

    describe('tree.getProof()', () => {
        it('should compute the membership proof of non-zero leaf', () => {
            const leafIdx = 3;
            const honestProof = honestTree
                .getProof(bigIntToBuffer(leaves[leafIdx]), leafIdx)
                .map(leaf => bufferToBigInt(leaf.data));
            const testProof = testTree.getProof(leafIdx);

            expect(testProof).to.be.of.length(honestProof.length);
            testProof.forEach((leaf, idx) => {
                expect(leaf).to.be.eq(honestProof[idx]);
            });
        });

        it('should compute the membership proof of any zero leaf', () => {
            const leafIdx = 200;
            const honestProof = honestTree
                .getProof(bigIntToBuffer(poseidon([BigInt(0)])), leafIdx)
                .map(leaf => bufferToBigInt(leaf.data));
            const testProof = testTree.getProof(leafIdx);

            expect(testProof).to.be.of.length(honestProof.length);
            testProof.forEach((leaf, idx) => {
                expect(leaf).to.be.eq(honestProof[idx]);
            });
        });

        it('should generate proof for zero leaves', () => {
            const testProof = testTree.getProof(100);
            const honestProof = honestTree
                .getProof(bigIntToBuffer(testTree.zeroValue), 100)
                .map(leaf => bufferToBigInt(leaf.data));
            expect(testProof).to.be.deep.eq(honestProof);
        });

        it('should throw error of invlaid leaf index/id', () => {
            expect(() => {
                testTree.getProof(2_000);
            }).to.throw('[getProof] invalid leaf index');
        });
    });

    describe('tree.verifyProof()', () => {
        it('should accept honest merkle proof', () => {
            const leafIdx = 1;
            const leaf = leaves[1];
            const honestProof = honestTree
                .getProof(bigIntToBuffer(leaf))
                .map(leaf => bufferToBigInt(leaf.data));

            expect(testTree.verifyProof(leaf, leafIdx, honestProof)).to.be.true;
        });

        it('should reject dishonest merkle proof', () => {
            const leafIdx = 1;
            const leaf = leaves[1];
            const honestProof = honestTree
                .getProof(bigIntToBuffer(leaf))
                .map(leaf => bufferToBigInt(leaf.data));

            // Manipulate the proof
            honestProof[1] = BigInt(1);

            expect(testTree.verifyProof(leaf, leafIdx, honestProof)).to.be
                .false;
        });

        it('should throw error for invalid leaf index/id', () => {
            expect(() => {
                testTree.verifyProof(BigInt(0), 2_000, []);
            }).to.throw('[verifyProof] invalid leaf index');
        });

        it('should reject correct merkle path with incorrect leaf index/id', () => {
            const leafIdx = 1;
            const leaf = leaves[1];
            const honestProof = honestTree
                .getProof(bigIntToBuffer(leaf))
                .map(leaf => bufferToBigInt(leaf.data));

            expect(testTree.verifyProof(leaf, leafIdx + 100, honestProof)).to.be
                .false;
        });
    });

    it('should compute the membership proof', () => {
        const leaves = [1, 2, 3, 4].map(leaf => poseidon([BigInt(leaf)]));
        const zeroValue = BigInt(0);
        const zeroValueHash = poseidon([zeroValue]);
        const depth = 3;

        const tree = new SparseMerkleTree(leaves, depth, zeroValueHash);
        const root = tree.getRoot();

        const l1 = leaves[2];
        const l2 = leaves[3];
        const l3 = poseidon([leaves[0], leaves[1]]);
        const l4 = poseidon([
            poseidon([zeroValueHash, zeroValueHash]),
            poseidon([zeroValueHash, zeroValueHash]),
        ]);

        const h1 = poseidon([l1, l2]);
        const h2 = poseidon([l3, h1]);
        const h3 = poseidon([h2, l4]);
        expect(root).to.be.eq(h3);

        const path = tree.getProof(2);

        expect(path).to.be.of.length(3);
        expect(path[0]).to.be.eq(l2);
        expect(path[1]).to.be.eq(l3);
        expect(path[2]).to.be.eq(l4);

        const isValidProof = tree.verifyProof(l1, 2, path);
        expect(isValidProof).to.be.eq(true);
    });

    describe('tree.getRoot()', () => {
        it('should return the root node for the tree', () => {
            const leaves = [1, 2, 3].map(leaf => poseidon([BigInt(leaf)]));
            const zeroValue = BigInt(0);
            const zeroValueHash = poseidon([zeroValue]);
            const depth = 2;
            const tree = new SparseMerkleTree(leaves, depth, zeroValueHash);

            const l1 = [...leaves, zeroValueHash];
            const l2 = [
                [0, 1],
                [2, 3],
            ].map(hash(l1));
            const l3 = [[0, 1]].map(hash(l2));

            const root = tree.getRoot();
            expect(root).to.be.eq(l3[0]);
        });

        it('should return the top default hash if no leaves', () => {
            const zeroValue = BigInt(0);
            const depth = 2;
            const tree = new SparseMerkleTree(
                [],
                depth,
                zeroValue,
                true, // shouldHash
            );

            const zeroValueHash = poseidon([zeroValue]);
            const parentHash = poseidon([zeroValueHash, zeroValueHash]);
            expect(tree.getRoot()).to.be.eq(poseidon([parentHash, parentHash]));
        });

        it('should match the root generated by merkletreejs', () => {
            const depth = 6;
            const zeroValue = BigInt(0);
            const honestTree = new HonestMekleTree(
                [],
                poseidon([zeroValue]),
                Math.pow(2, depth), // 64 leaves
            );

            const tree = new SparseMerkleTree(
                [],
                depth,
                zeroValue,
                true, // shouldHash
            );
            expect(tree.getRoot()).to.be.eq(
                bufferToBigInt(honestTree.getRoot()),
            );
        });
    });

    describe('tree.isEmpty()', () => {
        it('should return true for empty trees', () => {
            const tree = new SparseMerkleTree([], 3);
            expect(tree.isEmpty()).to.be.true;
        });
        it('should return false for non-empty trees', () => {
            expect(testTree.isEmpty()).to.be.false;
        });
    });
});
