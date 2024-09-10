// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {
    TAXI_SUBTREE_DEPTH,
    TAXI_TREE_DEPTH,
    TAXI_TREE_DEPTH_WITH_SUBTREE,
    TREE_ZERO_LEAF,
    ABSTRACTED_TAXI_TREE_DEPTH,
} from './constants';
import {
    AbstractedSubtreeProofError,
    LeafIndexOutOfBound,
    InvalidSubtreeIndex,
} from './errors';
import {SparseMerkleTree} from './sparse-merkle-tree';

/**
 * List of tree leaves or its root
 */
type AbstractTree = bigint[] | bigint;

/**
 * ## `TaxiTree`
 *
 * Taxi tree is implemented as a sparse merkle tree of depth 8. it has two
 * subtrees of depth 7.
 *
 */
export class TaxiTree {
    private subtrees: [SparseMerkleTree, SparseMerkleTree];
    private tree: SparseMerkleTree; // main taxi tree
    public leafCount: number;

    constructor({left, right}: {left: AbstractTree; right: AbstractTree}) {
        this.subtrees = [
            TaxiTree.buildSubtree(left),
            TaxiTree.buildSubtree(right),
        ];
        const zero = TaxiTree.buildSubtree([]).getRoot();
        this.tree = new SparseMerkleTree(
            this.subtrees.map(subtree => subtree.getRoot()),
            TAXI_TREE_DEPTH_WITH_SUBTREE,
            zero,
        );
        this.leafCount = 2 ** TAXI_TREE_DEPTH;
    }

    public getRoot(): bigint {
        return this.tree.getRoot();
    }

    public getProof(leafIndex: number): bigint[] {
        if (leafIndex >= this.leafCount || leafIndex < 0)
            throw new LeafIndexOutOfBound(leafIndex);

        const subtreeLeafIndex = leafIndex % 2 ** TAXI_SUBTREE_DEPTH;
        const subtreeIndex = this.asSubtreeIndex(leafIndex);
        const subtree = this.subtrees[subtreeIndex];

        if (!subtree) throw new InvalidSubtreeIndex(subtreeIndex);
        if (this.isAbstracted(subtreeIndex))
            throw new AbstractedSubtreeProofError();

        const subtreeProof =
            this.subtrees[subtreeIndex].getProof(subtreeLeafIndex);
        const treeProof = this.tree.getProof(subtreeIndex);
        return [...subtreeProof, ...treeProof];
    }

    private isAbstracted(subtreeIndex: number) {
        return this.subtrees[subtreeIndex].depth === ABSTRACTED_TAXI_TREE_DEPTH;
    }

    private asSubtreeIndex(index: number) {
        return Math.floor(index / 2 ** TAXI_SUBTREE_DEPTH);
    }

    private static buildSubtree(values: bigint[] | bigint): SparseMerkleTree {
        const isRoot = typeof values === 'bigint';
        const leaves = isRoot ? [values] : values;
        const depth = isRoot ? ABSTRACTED_TAXI_TREE_DEPTH : TAXI_SUBTREE_DEPTH;
        const zero = BigInt(TREE_ZERO_LEAF);
        return new SparseMerkleTree(leaves, depth, zero);
    }
}
