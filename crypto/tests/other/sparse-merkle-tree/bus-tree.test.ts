// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2022-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {range} from 'lodash';

import {BusTree} from '../../../src/other/sparse-merkle-tree';

function createBusTree(
    utxoPackIndex: number,
    utxoPackLeaves: bigint[],
    utxoPackRoots: bigint[],
    branchRoots: bigint[],
    utxoPackDepth: number,
    branchDepth: number,
    depth: number,
): BusTree {
    return new BusTree(
        utxoPackIndex,
        utxoPackLeaves,
        utxoPackRoots,
        branchRoots,
        utxoPackDepth,
        branchDepth,
        depth,
    );
}

describe('BusTree', () => {
    const defaultLeaves = [0, 1, 2, 3].map(BigInt);
    const defaultRoots = [0, 1, 2, 3].map(BigInt);
    const utxoPackDepth = 2;
    const branchDepth = 2;
    const depth = 6;

    it('returns correct root', () => {
        const smt = createBusTree(
            0,
            defaultLeaves,
            defaultRoots,
            defaultRoots,
            utxoPackDepth,
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
            utxoPackDepth,
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
            utxoPackDepth,
            branchDepth,
            depth,
        );

        expect(() => smt.verifyProof(BigInt(0), 5, smt.getProof(0))).to.throw(
            'Pack index 1 is not in the same UTXO pack as the bus tree 0',
        );
    });

    it('throws an error for zero leaf', () => {
        const smt = createBusTree(
            0,
            [0].map(BigInt),
            [],
            [],
            utxoPackDepth,
            branchDepth,
            depth,
        );

        expect(() => smt.verifyProof(BigInt(1), 1, smt.getProof(1))).to.throw(
            'Leaf 1 does not match the leaf 0 in the UTXO pack',
        );
    });

    it('fails to verify an incorrect proof', () => {
        const smt = createBusTree(
            0,
            defaultLeaves,
            defaultRoots,
            defaultRoots,
            utxoPackDepth,
            branchDepth,
            depth,
        );

        const invalidProof = smt.getProof(0);
        invalidProof[invalidProof.length - 1] = BigInt(5);
        expect(smt.verifyProof(BigInt(0), 0, invalidProof)).to.be.false;
    });

    it('fails if filled UTXO pack roots on the left are not provided', () => {
        expect(() => {
            createBusTree(
                6,
                [0, 1].map(BigInt),
                [], // utxo pack roots
                [],
                1,
                1,
                3,
            );
        }).to.throw(
            'Roots of the UTXO packs length (0) must have at least elements (1)',
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
});
