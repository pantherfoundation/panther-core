// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2022-23 Panther Ventures Limited Gibraltar

import assert from 'assert';

import {inRange} from 'lodash';

import {SparseMerkleTree} from './sparse-merkle-tree';

export class TreeOfTrees {
    private tree: SparseMerkleTree;
    private depth: number;
    readonly subtreesCount: number;
    readonly leafCount: number;
    private subtrees: SparseMerkleTree[];
    private zeroTree: SparseMerkleTree;

    constructor(
        subtrees: SparseMerkleTree[],
        depth: number,
        zeroTree: {
            depth: number;
            zeroValue?: bigint;
            shouldHash?: boolean;
        },
    ) {
        this.subtrees = subtrees;
        this.zeroTree = new SparseMerkleTree(
            [],
            zeroTree.depth,
            zeroTree.zeroValue,
            zeroTree.shouldHash,
        );
        this.depth = depth;
        this.subtreesCount = Math.pow(2, depth);
        this.leafCount = this.subtreesCount * this.zeroTree.leafCount;
        this.tree = this.processTree();
    }

    public getLeaf(leafId: number): bigint {
        const [subtreeIdx, leafIdx] = this.leafIdAsIdx(leafId);

        assert(
            this.isValidSubtreeIdx(subtreeIdx),
            '[getLeaf] invalid leaf id. Subtree not found.',
        );

        const subtree = this.subtrees[subtreeIdx] || this.zeroTree;

        return subtree.getLeaf(leafIdx);
    }

    public addLeaf(leaf: bigint, shouldHash = false): TreeOfTrees {
        assert(!this.isFull(), '[addLeaf] tree overflow. Tree is full.');
        const subtree = this.subtrees.find(subtree => !subtree.isFull());
        if (subtree) subtree.addLeaf(leaf);
        else {
            this.subtrees.push(
                new SparseMerkleTree(
                    [leaf],
                    this.zeroTree.depth,
                    this.zeroTree.zeroValue,
                    shouldHash,
                ),
            );
        }

        return this;
    }

    public getRoot(): bigint {
        return this.tree.getRoot();
    }

    public getProof(leafId: number): bigint[] {
        const [subtreeIdx, leafIdx] = this.leafIdAsIdx(leafId);

        assert(
            this.isValidSubtreeIdx(subtreeIdx),
            '[getProof] invalid leaf id. Subtree not found.',
        );

        const subtree = this.subtrees[subtreeIdx] || this.zeroTree;
        const subtreeProof = subtree.getProof(leafIdx);
        const treeProof = this.tree.getProof(subtreeIdx);

        return subtreeProof.concat(treeProof);
    }

    public leafIdAsIdx(leafId: number): [treeIdx: number, leafIdx: number] {
        assert(this.isValidLeafId(leafId), '[leafIdAsIdx] invalid leaf id');

        for (
            let subtreeIdx = 0;
            subtreeIdx < this.subtreesCount;
            subtreeIdx++
        ) {
            const subtree = this.subtrees[subtreeIdx] || this.zeroTree;
            const numOfLeavesPerSubtree = Math.pow(2, subtree.depth);

            const start = subtreeIdx * numOfLeavesPerSubtree;
            const end = start + numOfLeavesPerSubtree;

            if (inRange(leafId, start, end))
                return [subtreeIdx, leafId - start];
        }

        throw new Error('[leafIdAsIdx] invalid leaf id. Should never happen');
    }

    public verifyProof(
        leaf: bigint,
        leafId: number,
        merklePath: bigint[],
    ): boolean {
        const [subtreeIdx, leafIdx] = this.leafIdAsIdx(leafId);
        const subtree = this.getSubtree(subtreeIdx);

        const isValidSubtreeProof = subtree.verifyProof(
            leaf,
            leafIdx,
            merklePath.slice(0, subtree.depth),
        );

        if (!isValidSubtreeProof) return false;

        return this.tree.verifyProof(
            subtree.getRoot(),
            subtreeIdx,
            merklePath.slice(-this.tree.depth),
        );
    }

    private processTree(): SparseMerkleTree {
        return new SparseMerkleTree(
            this.subtrees.map(subtree => subtree.getRoot()),
            this.depth,
            this.zeroTree.getRoot(),
        );
    }

    public getSubtree(subtreeIdx: number): SparseMerkleTree {
        assert(
            this.isValidSubtreeIdx(subtreeIdx),
            '[getSubtree] invalid subtree index',
        );
        return this.subtrees[subtreeIdx] || this.zeroTree;
    }

    public isValidLeafId(leafId: number): boolean {
        const leafCount = this.subtreesCount * this.zeroTree.leafCount;
        return leafId >= 0 && leafId < leafCount;
    }

    public isValidSubtreeIdx(subtreeIdx: number): boolean {
        return subtreeIdx >= 0 && subtreeIdx < Math.pow(2, this.depth);
    }

    public isFull(): boolean {
        return (
            this.subtrees.length === this.subtreesCount &&
            this.subtrees.every(subtree => subtree.isFull())
        );
    }

    public isEmpty(): boolean {
        return (
            this.subtrees.length !== this.subtreesCount &&
            this.subtrees.every(subtree => subtree.isEmpty())
        );
    }
}
