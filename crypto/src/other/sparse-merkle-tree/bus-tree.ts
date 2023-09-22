// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import poseidon from 'circomlibjs/src/poseidon';

import {SparseMerkleTree} from './sparse-merkle-tree';

/**
 BusTree is responsible for generating and managing three-tiered Merkle tree
 that is composed of UTXO batch/queue, branch, and root trees.

                            Root Tree
                             /  |  \
                            /   |   \
                           /    |    \
                          /     |     \
                    Branch Tree  |   Branch Tree
                       /  |  \   |     /  |  \
                      /   |   \  |    /   |   \
                     /    |    \ |   /    |    \
                UTXO Batch | UTXO Batch | UTXO Batch
                   /  |  \  |    /  |  \  |   /  |  \
                  L   L   L |   L   L   L |  L   L   L
                  e   e   e |   e   e   e |  e   e   e
                  a   a   a |   a   a   a |  a   a   a
                  f   f   f |   f   f   f |  f   f   f


This tree has three levels:
- The root tree: It is composed of branches (Branch Trees);
- Branch tree: Each branch is composed of UTXO batches (UTXO Batch Trees);
- UTXO Batch tree: Each UTXO batch is composed of leaves (transactions);

Please note that the above diagram is an oversimplified representation for
better understanding. In reality, the depth of the tree can vary depending on
the parameters provided while constructing the BusTree object, and each tree can
potentially have 2^n nodes, where n is the depth of the tree.

   */

export class BusTree {
    private readonly utxoBatchTree: SparseMerkleTree;
    private readonly branchTree: SparseMerkleTree;
    private readonly rootTree: SparseMerkleTree;
    private readonly utxoBatchIndex: number;

    /**
     * Constructor for BusTree.
     * @param {number} leftLeafIndex - Starting index of the left leaf.
     * @param {bigint[]} utxoBatchLeaves - Leaves of the UTXO batch.
     * @param {bigint[]} utxoBatchRoots - Roots of the UTXO batches in the branch.
     * @param {bigint[]} branchRoots - Roots of the branches.
     * @param {number} utxoBatchDepth - Depth of the UTXO batch.
     * @param {number} branchDepth - Depth of the branch.
     * @param {number} depth - Total depth.
     * @param {bigint} zeroValue - Value to fill in non-existent leaves, defaults to 0.
     */
    constructor(
        leftLeafIndex: number,
        utxoBatchLeaves: bigint[],
        private utxoBatchRoots: bigint[],
        private branchRoots: bigint[],
        private readonly utxoBatchDepth: number,
        private readonly branchDepth: number,
        private readonly depth: number,
        zeroValue = BigInt(0),
    ) {
        this.validateDepths(utxoBatchDepth, branchDepth, depth);

        this.utxoBatchIndex = this.calculateBranchIndex(
            leftLeafIndex,
            utxoBatchDepth,
            branchDepth,
        );
        this.validateInputRootsLength(
            'Roots of the UTXO batches',
            this.utxoBatchIndex,
            utxoBatchRoots,
        );

        // Initialize UTXO batch tree and update the UTXO batch root in the branch
        this.utxoBatchTree = this.initTree(
            utxoBatchLeaves,
            this.utxoBatchDepth,
            zeroValue,
        );

        this.utxoBatchRoots[this.utxoBatchIndex] = this.utxoBatchTree.getRoot();

        // Initialize branch tree and update the branch root
        this.branchTree = this.initTree(
            this.utxoBatchRoots,
            this.branchDepth,
            this.utxoBatchTree.getDefaultRoot(),
        );

        const branchIndex = this.calculateBranchIndex(
            this.calculateSubtreeIndex(leftLeafIndex, utxoBatchDepth), // absolute utxo batch index
            this.branchDepth,
            this.depth - this.branchDepth - this.utxoBatchDepth,
        );

        this.validateInputRootsLength(
            'Roots of the branches',
            branchIndex,
            branchRoots,
        );
        this.branchRoots[branchIndex] = this.branchTree.getRoot();

        // Initialize root tree
        this.rootTree = this.initTree(
            this.branchRoots,
            depth - this.branchDepth - this.utxoBatchDepth,
            this.branchTree.getDefaultRoot(),
        );
    }

    /**
     * Validates that depths are positive integers and the sum of utxoBatchDepth and branchDepth is less than the total depth.
     * @throws Will throw an Error if the depths are not valid.
     */
    private validateDepths(
        utxoBatchDepth: number,
        branchDepth: number,
        depth: number,
    ): void {
        if (utxoBatchDepth <= 0 || branchDepth <= 0 || depth <= 0) {
            throw new Error('Depths must be positive integers.');
        }
        if (utxoBatchDepth + branchDepth >= depth) {
            throw new Error(
                'The sum of utxoBatchDepth and branchDepth must be less than the total depth.',
            );
        }
    }

    private calculateSubtreeIndex(
        leafIndex: number,
        depthLevelOfSubtreeRoot: number,
    ): number {
        return Math.floor(leafIndex / 2 ** depthLevelOfSubtreeRoot);
    }

    /**
     * Calculates the branch index.
     * @returns {number} The calculated branch index.
     */
    private calculateBranchIndex(
        leafIndex: number,
        depthAtThatLevel: number,
        branchDepth: number,
    ): number {
        return (
            this.calculateSubtreeIndex(leafIndex, depthAtThatLevel) %
            2 ** branchDepth
        );
    }

    public getBatchIndex(leafIndex: number): number {
        return leafIndex >> this.utxoBatchDepth;
    }

    public getBranchIndex(leafIndex: number): number {
        return leafIndex >> (this.utxoBatchDepth + this.branchDepth);
    }

    public getLeftLeafIndex(batchIndex: number): number {
        return batchIndex * 2 ** this.utxoBatchDepth;
    }
    /**
     * Validates that an array has at least batchIndex elements.
     * @throws Will throw an Error if the array is not long enough.
     */
    private validateInputRootsLength(
        name: string,
        rootIndex: number,
        roots: bigint[],
    ): void {
        if (roots.length < rootIndex) {
            throw new Error(
                `${name} length (${roots.length}) must have at least elements (${rootIndex})`,
            );
        }
    }

    /**
     * Initialize a SparseMerkleTree.
     * @param {bigint[]} leaves - Leaves for the tree.
     * @param {number} depth - Depth of the tree.
     * @param {bigint} zeroValue - Value to fill in non-existent leaves.
     * @returns {SparseMerkleTree} A SparseMerkleTree instance.
     */
    private initTree(
        leaves: bigint[],
        depth: number,
        zeroValue: bigint,
    ): SparseMerkleTree {
        return new SparseMerkleTree(leaves, depth, zeroValue);
    }

    /**
     * Returns the root of the root tree.
     * @returns {bigint} Root of the root tree as a BigInt.
     */
    public getRoot(): bigint {
        return this.rootTree.getRoot();
    }

    /**
     * Returns the Merkle proof for a given leaf index.
     * @param {number} leafIndex - The index of the leaf to generate a proof for.
     * @throws Will throw an Error if the UTXO batch index does not match.
     * @returns {bigint[]} An array of BigInt representing the Merkle proof.
     */
    public getProof(leafIndex: number): bigint[] {
        const utxoBatchIndex = this.calculateBranchIndex(
            leafIndex,
            this.utxoBatchDepth,
            this.branchDepth,
        );

        this.validateBatchIndex(utxoBatchIndex);

        const leafIndexInBatch = leafIndex % 2 ** this.utxoBatchDepth;
        const branchIndex = this.calculateBranchIndex(
            leafIndex,
            this.branchDepth,
            this.depth,
        );

        const utxoBatchProof = this.utxoBatchTree.getProof(leafIndexInBatch);
        const branchProof = this.branchTree.getProof(utxoBatchIndex);
        const rootProof = this.rootTree.getProof(branchIndex);

        return [...utxoBatchProof, ...branchProof, ...rootProof];
    }

    /**
     * Validates that the batch index matches the UTXO batch index.
     * @throws Will throw an Error if the batch index does not match.
     */
    private validateBatchIndex(batchIndex: number): void {
        if (batchIndex !== this.utxoBatchIndex) {
            throw new Error(
                `Batch index ${batchIndex} is not in the same UTXO batch as the bus tree ${this.utxoBatchIndex}`,
            );
        }
    }

    /**
     * Verifies the given Merkle proof against the leaf.
     * @param {bigint} leaf - The leaf to verify.
     * @param {number} leafIndex - The index of the leaf.
     * @param {bigint[]} merklePath - The Merkle proof to verify.
     * @throws Will throw an Error if the UTXO batch index does not match.
     * @throws Will throw an Error if the leaf does not match.
     * @returns {boolean} True if the proof is valid, false otherwise.
     */
    public verifyProof(
        leaf: bigint,
        leafIndex: number,
        merklePath: bigint[],
    ): boolean {
        const utxoBatchIndex = this.calculateBranchIndex(
            leafIndex,
            this.utxoBatchDepth,
            this.branchDepth,
        );

        this.validateBatchIndex(utxoBatchIndex);

        const leafInBatch = this.utxoBatchTree.getLeaf(
            leafIndex % 2 ** this.utxoBatchDepth,
        );
        this.validateLeaf(leaf, leafInBatch);

        return (
            this.calculateHash(leaf, leafIndex, merklePath) === this.getRoot()
        );
    }

    /**
     * Calculates hash based on given parameters.
     * @param {bigint} leaf - The leaf to verify.
     * @param {number} index - The index of the leaf.
     * @param {bigint[]} merklePath - The Merkle proof to verify.
     * @returns {bigint} Resulting hash as a BigInt.
     */
    private calculateHash(
        leaf: bigint,
        index: number,
        merklePath: bigint[],
    ): bigint {
        let currentNodeHash: bigint = leaf;

        for (const path of merklePath) {
            const isRight = index % 2 === 1;
            currentNodeHash = poseidon(
                isRight ? [path, currentNodeHash] : [currentNodeHash, path],
            );
            index >>= 1;
        }
        return currentNodeHash;
    }

    /**
     * Validates that a leaf matches a specified leaf.
     * @throws Will throw an Error if the leaves do not match.
     */
    private validateLeaf(leaf: bigint, leafInBatch: bigint): void {
        if (leafInBatch !== leaf) {
            throw new Error(
                `Leaf ${leaf} does not match the leaf ${leafInBatch} in the UTXO batch`,
            );
        }
    }
}
