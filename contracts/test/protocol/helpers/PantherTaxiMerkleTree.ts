// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';

export class PantherTaxiMerkleTree {
    public leftSubtree: MerkleTree;
    public rightSubtree: MerkleTree;
    private zeroLeaf: string;
    private primarySubtreeIndicator: number; // 0 for left, 1 for right
    public root: string;
    private totalLeavesInserted: number;

    constructor(zeroLeaf: string) {
        this.zeroLeaf = zeroLeaf;
        this.primarySubtreeIndicator = 0; // Start with left subtree as primary
        this.totalLeavesInserted = 0;

        this.leftSubtree = new MerkleTree(poseidon, 7, zeroLeaf); // 128 leaves
        this.rightSubtree = new MerkleTree(poseidon, 7, zeroLeaf); // 128 leaves

        this.root = poseidon([
            this.leftSubtree.root,
            this.rightSubtree.root,
        ]).toString();
    }

    private isFull(subtree: MerkleTree): boolean {
        return subtree.leaves.length >= 2 ** subtree.depth;
    }

    private isEmpty(): boolean {
        return this.totalLeavesInserted === 0;
    }

    private resetSubtree(subtree: 'left' | 'right'): void {
        if (subtree === 'left') {
            this.leftSubtree = new MerkleTree(poseidon, 7, this.zeroLeaf);
            this.primarySubtreeIndicator = 1;
        } else {
            this.rightSubtree = new MerkleTree(poseidon, 7, this.zeroLeaf);
            this.primarySubtreeIndicator = 0;
        }
    }

    public insertLeaf(leaf: string): void {
        if (this.isEmpty() || !this.isFull(this.leftSubtree)) {
            // Insert in the left subtree if it's not full or the tree is empty
            this.leftSubtree.insert(leaf);
        } else if (
            this.isFull(this.leftSubtree) &&
            !this.isFull(this.rightSubtree)
        ) {
            // If the left subtree is full, insert into the right subtree
            this.rightSubtree.insert(leaf);
        } else if (
            this.isFull(this.leftSubtree) &&
            this.isFull(this.rightSubtree) &&
            this.primarySubtreeIndicator == 0
        ) {
            // If both subtrees are full, reset the left subtree and start inserting again
            this.resetSubtree('left');
            this.leftSubtree.insert(leaf);
        } else if (
            this.isFull(this.leftSubtree) &&
            this.primarySubtreeIndicator === 1
        ) {
            // When the left subtree is full and primary is right, reset the right subtree
            this.resetSubtree('right');
            this.rightSubtree.insert(leaf);
        }

        // Update the total leaves inserted and the root of the entire tree
        this.totalLeavesInserted++;
        this.updateRoot();
    }

    private updateRoot(): void {
        this.root = poseidon([
            this.leftSubtree.root,
            this.rightSubtree.root,
        ]).toString();
    }
}
