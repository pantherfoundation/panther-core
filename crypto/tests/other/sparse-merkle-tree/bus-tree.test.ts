// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {range} from 'lodash';

import {
    BusTree,
    BUS_TREE_BATCH_DEPTH,
    BUS_TREE_BRANCH_DEPTH,
    BUS_TREE_DEPTH,
    BUS_TREE_ZERO_LEAF,
} from '../../../src/other/sparse-merkle-tree';

import busTreeData from './data/bus-tree.json';

const asBigInt = (items: string[]): bigint[] => items.map(BigInt);

function createBusTree(
    utxoBatchIndex: number,
    utxoBatchLeaves: bigint[],
    utxoBatchRoots: bigint[],
    branchRoots: bigint[],
    utxoBatchDepth: number,
    branchDepth: number,
    depth: number,
): BusTree {
    return new BusTree(
        utxoBatchIndex,
        utxoBatchLeaves,
        utxoBatchRoots,
        branchRoots,
        utxoBatchDepth,
        branchDepth,
        depth,
    );
}

describe('BusTree', () => {
    const defaultLeaves = [0, 1, 2, 3].map(BigInt);
    const defaultRoots = [0, 1, 2, 3].map(BigInt);
    const utxoBatchDepth = 2;
    const branchDepth = 2;
    const depth = 6;

    it('returns correct root', () => {
        const smt = createBusTree(
            0,
            defaultLeaves,
            defaultRoots,
            defaultRoots,
            utxoBatchDepth,
            branchDepth,
            depth,
        );

        expect(smt.getRoot()).to.equal(
            15399230881225818932954988305406984933449035880369184569859134619700414717686n,
        );
    });

    it('verifies proof for all leaf indices', () => {
        const smt = createBusTree(
            0,
            defaultLeaves,
            [],
            [],
            utxoBatchDepth,
            branchDepth,
            depth,
        );

        range(4).forEach(i => {
            expect(smt.verifyProof(BigInt(i), i, smt.getProof(i))).to.be.true;
        });
    });

    it('throws an error for invalid leaf index', () => {
        const smt = createBusTree(
            0,
            defaultLeaves,
            defaultRoots,
            defaultRoots,
            utxoBatchDepth,
            branchDepth,
            depth,
        );

        expect(() => smt.verifyProof(BigInt(0), 5, smt.getProof(0))).to.throw(
            'Batch index 1 is not in the same UTXO batch as the bus tree 0',
        );
    });

    it('throws an error for zero leaf', () => {
        const smt = createBusTree(
            0,
            [0].map(BigInt),
            [],
            [],
            utxoBatchDepth,
            branchDepth,
            depth,
        );

        expect(() => smt.verifyProof(BigInt(1), 1, smt.getProof(1))).to.throw(
            'Leaf 1 does not match the leaf 0 in the UTXO batch',
        );
    });

    it('fails to verify an incorrect proof', () => {
        const smt = createBusTree(
            0,
            defaultLeaves,
            defaultRoots,
            defaultRoots,
            utxoBatchDepth,
            branchDepth,
            depth,
        );

        const invalidProof = smt.getProof(0);
        invalidProof[invalidProof.length - 1] = BigInt(5);
        expect(smt.verifyProof(BigInt(0), 0, invalidProof)).to.be.false;
    });

    it('fails if filled UTXO batch roots on the left are not provided', () => {
        expect(() => {
            createBusTree(
                6,
                [0, 1].map(BigInt),
                [], // utxo batch roots
                [],
                1,
                1,
                3,
            );
        }).to.throw(
            'Roots of the UTXO batches length (0) must have at least elements (1)',
        );
    });

    it('fails if filled branch roots on the left are not provided', () => {
        expect(() => {
            createBusTree(
                4,
                [0, 1].map(BigInt),
                [],
                [], // branch roots
                1,
                1,
                3,
            );
        }).to.throw(
            'Roots of the branches length (0) must have at least elements (1',
        );
    });

    it('should calculate the correct batch & branch index for a given leaf index', () => {
        const tree = createBusTree(
            0,
            defaultLeaves,
            defaultRoots,
            defaultRoots,
            utxoBatchDepth,
            branchDepth,
            depth,
        );

        const indexes = [
            {
                leafIndex: 1,
                leftLeafIndex: 0,
                batchIndex: 0,
                branchIndex: 0,
            },
            {
                leafIndex: 5,
                leftLeafIndex: 4,
                batchIndex: 1,
                branchIndex: 0,
            },
            {
                leafIndex: 18,
                leftLeafIndex: 16,
                batchIndex: 4,
                branchIndex: 1,
            },
        ];

        indexes.forEach(
            ({leafIndex, batchIndex, branchIndex, leftLeafIndex}) => {
                expect(tree.getBatchIndex(leafIndex)).to.be.eq(batchIndex);
                expect(tree.getBranchIndex(leafIndex)).to.be.eq(branchIndex);
                expect(tree.getLeftLeafIndex(batchIndex)).to.be.eq(
                    leftLeafIndex,
                );
            },
        );
    });

    it('should be able to generate BusTree with real subgraph data', () => {
        const tree = new BusTree(
            busTreeData.leftLeafIndex,
            asBigInt(busTreeData.utxoBatchLeaves),
            asBigInt(busTreeData.utxoBatchRoots),
            asBigInt(busTreeData.branchRoots),
            BUS_TREE_BATCH_DEPTH,
            BUS_TREE_BRANCH_DEPTH,
            BUS_TREE_DEPTH,
            BigInt(BUS_TREE_ZERO_LEAF),
        );

        expect(tree.getRoot()).to.be.eq(BigInt(busTreeData.busTreeRoot));
    });
});
