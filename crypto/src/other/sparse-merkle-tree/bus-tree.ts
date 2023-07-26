// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import poseidon from 'circomlibjs/src/poseidon';

import {SparseMerkleTree} from './sparse-merkle-tree';

/**
 BusTree is responsible for generating and managing three-tiered Merkle tree
 that is composed of UTXO pack/queue, branch, and root trees.

                            Root Tree
                             /  |  \
                            /   |   \
                           /    |    \
                          /     |     \
                    Branch Tree  |   Branch Tree
                       /  |  \   |     /  |  \
                      /   |   \  |    /   |   \
                     /    |    \ |   /    |    \
                UTXO Pack | UTXO Pack | UTXO Pack
                   /  |  \  |    /  |  \  |   /  |  \
                  L   L   L |   L   L   L |  L   L   L
                  e   e   e |   e   e   e |  e   e   e
                  a   a   a |   a   a   a |  a   a   a
                  f   f   f |   f   f   f |  f   f   f


This tree has three levels:
- The root tree: It is composed of branches (Branch Trees);
- Branch tree: Each branch is composed of UTXO packs (UTXO Pack Trees);
- UTXO Pack tree: Each UTXO pack is composed of leaves (transactions);

Please note that the above diagram is an oversimplified representation for
better understanding. In reality, the depth of the tree can vary depending on
the parameters provided while constructing the BusTree object, and each tree can
potentially have 2^n nodes, where n is the depth of the tree.

   */

export class BusTree {
    private readonly utxoPackTree: SparseMerkleTree;
    private readonly branchTree: SparseMerkleTree;
    private readonly rootTree: SparseMerkleTree;
    private readonly utxoPackIndex: number;

    /**
     * Constructor for BusTree.
     * @param {number} leftLeafIndex - Starting index of the left leaf.
     * @param {bigint[]} leavesOfUtxoPack - Leaves of the UTXO pack.
     * @param {bigint[]} rootsOfUtxoPacksInBranch - Roots of the UTXO packs in the branch.
     * @param {bigint[]} rootsOfBranches - Roots of the branches.
     * @param {number} utxoPackDepth - Depth of the UTXO pack.
     * @param {number} branchDepth - Depth of the branch.
     * @param {number} depth - Total depth.
     * @param {bigint} zeroValue - Value to fill in non-existent leaves, defaults to 0.
     */
    constructor(
        leftLeafIndex: number,
        leavesOfUtxoPack: bigint[],
        private rootsOfUtxoPacksInBranch: bigint[],
        private rootsOfBranches: bigint[],
        private readonly utxoPackDepth: number,
        private readonly branchDepth: number,
        private readonly depth: number,
        zeroValue = BigInt(0),
    ) {
        this.validateDepths(utxoPackDepth, branchDepth, depth);

        this.utxoPackIndex = this.calculateBranchIndex(
            leftLeafIndex,
            utxoPackDepth,
            branchDepth,
        );
        this.validateInputRootsLength(
            'Roots of the UTXO packs',
            this.utxoPackIndex,
            rootsOfUtxoPacksInBranch,
        );

        // Initialize UTXO pack tree and update the UTXO pack root in the branch
        this.utxoPackTree = this.initTree(
            leavesOfUtxoPack,
            this.utxoPackDepth,
            zeroValue,
        );

        this.rootsOfUtxoPacksInBranch[this.utxoPackIndex] =
            this.utxoPackTree.getRoot();

        // Initialize branch tree and update the branch root
        this.branchTree = this.initTree(
            this.rootsOfUtxoPacksInBranch,
            this.branchDepth,
            this.utxoPackTree.getDefaultRoot(),
        );

        const branchIndex = this.calculateBranchIndex(
            this.calculateSubtreeIndex(leftLeafIndex, utxoPackDepth), // absolute utxo pack index
            this.branchDepth,
            this.depth - this.branchDepth - this.utxoPackDepth,
        );

        this.validateInputRootsLength(
            'Roots of the branches',
            branchIndex,
            rootsOfBranches,
        );
        this.rootsOfBranches[branchIndex] = this.branchTree.getRoot();

        // Initialize root tree
        this.rootTree = this.initTree(
            this.rootsOfBranches,
            depth - this.branchDepth - this.utxoPackDepth,
            this.branchTree.getDefaultRoot(),
        );
    }

    /**
     * Validates that depths are positive integers and the sum of utxoPackDepth and branchDepth is less than the total depth.
     * @throws Will throw an Error if the depths are not valid.
     */
    private validateDepths(
        utxoPackDepth: number,
        branchDepth: number,
        depth: number,
    ): void {
        if (utxoPackDepth <= 0 || branchDepth <= 0 || depth <= 0) {
            throw new Error('Depths must be positive integers.');
        }
        if (utxoPackDepth + branchDepth >= depth) {
            throw new Error(
                'The sum of utxoPackDepth and branchDepth must be less than the total depth.',
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

    /**
     * Validates that an array has at least packIndex elements.
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
     * @throws Will throw an Error if the UTXO pack index does not match.
     * @returns {bigint[]} An array of BigInt representing the Merkle proof.
     */
    public getProof(leafIndex: number): bigint[] {
        const utxoPackIndex = this.calculateBranchIndex(
            leafIndex,
            this.utxoPackDepth,
            this.branchDepth,
        );

        this.validatePackIndex(utxoPackIndex);

        const leafIndexInPack = leafIndex % 2 ** this.utxoPackDepth;
        const branchIndex = this.calculateBranchIndex(
            leafIndex,
            this.branchDepth,
            this.depth,
        );

        const utxoPackProof = this.utxoPackTree.getProof(leafIndexInPack);
        const branchProof = this.branchTree.getProof(utxoPackIndex);
        const rootProof = this.rootTree.getProof(branchIndex);

        return [...utxoPackProof, ...branchProof, ...rootProof];
    }

    /**
     * Validates that the pack index matches the UTXO pack index.
     * @throws Will throw an Error if the pack index does not match.
     */
    private validatePackIndex(packIndex: number): void {
        if (packIndex !== this.utxoPackIndex) {
            throw new Error(
                `Pack index ${packIndex} is not in the same UTXO pack as the bus tree ${this.utxoPackIndex}`,
            );
        }
    }

    /**
     * Verifies the given Merkle proof against the leaf.
     * @param {bigint} leaf - The leaf to verify.
     * @param {number} leafIndex - The index of the leaf.
     * @param {bigint[]} merklePath - The Merkle proof to verify.
     * @throws Will throw an Error if the UTXO pack index does not match.
     * @throws Will throw an Error if the leaf does not match.
     * @returns {boolean} True if the proof is valid, false otherwise.
     */
    public verifyProof(
        leaf: bigint,
        leafIndex: number,
        merklePath: bigint[],
    ): boolean {
        const utxoPackIndex = this.calculateBranchIndex(
            leafIndex,
            this.utxoPackDepth,
            this.branchDepth,
        );

        this.validatePackIndex(utxoPackIndex);

        const leafInPack = this.utxoPackTree.getLeaf(
            leafIndex % 2 ** this.utxoPackDepth,
        );
        this.validateLeaf(leaf, leafInPack);

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
    private validateLeaf(leaf: bigint, leafInPack: bigint): void {
        if (leafInPack !== leaf) {
            throw new Error(
                `Leaf ${leaf} does not match the leaf ${leafInPack} in the UTXO pack`,
            );
        }
    }
}
