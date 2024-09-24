// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import assert from 'assert';

import {poseidon} from 'circomlibjs';

export class SparseMerkleTree {
    readonly zeroValue: bigint;
    readonly depth: number;
    readonly leafCount: number;
    private leaves: bigint[];
    private defaultHashes: bigint[] = [];
    private hash: (values: bigint[]) => bigint;
    private layers: bigint[][] = [];

    constructor(
        leaves: bigint[],
        depth: number,
        zeroValue = BigInt(0),
        shouldHash = false,
    ) {
        this.leafCount = Math.pow(2, depth);
        assert(
            leaves.length <= this.leafCount,
            `[SparseMerkleTree] tree overflow. Got "${leaves.length}" leaves. Expected to be less than ${this.leafCount}`,
        );
        this.hash = poseidon;
        this.leaves = shouldHash
            ? leaves.map(leaf => this.hash([leaf]))
            : leaves;
        this.zeroValue = shouldHash ? this.hash([zeroValue]) : zeroValue;
        this.depth = depth;

        this.defaultHashes = this.computeDefaultHashes();
        this.layers = this.processLeaves();
    }

    public getLeaf(leafIdx: number): bigint {
        assert(this.isValidLeafIdx(leafIdx), '[getLeaf] invalid leaf index');
        return this.leaves[leafIdx] || this.zeroValue;
    }

    public addLeaf(leaf: bigint, shouldHash = false): SparseMerkleTree {
        assert(!this.isFull(), '[addLeaf] tree is full');

        this.leaves.push(shouldHash ? this.hash([leaf]) : leaf);
        this.layers = this.processLeaves();

        return this;
    }

    public updateLeaf(
        leafIdx: number,
        value: bigint,
        shouldHash = false,
    ): SparseMerkleTree {
        assert(
            this.isValidLeafIdx(leafIdx, true),
            '[updateLeaf] invalid leaf index. should never update zero-valued leaf',
        );

        this.leaves[leafIdx] = shouldHash ? this.hash([value]) : value;
        this.layers = this.processLeaves();
        return this;
    }

    public removeLeaf(leafIdx: number): SparseMerkleTree {
        assert(
            this.isValidLeafIdx(leafIdx, true),
            '[removeLeaf] invalid leaf index. should never remove zero leaf',
        );

        this.leaves.splice(leafIdx, 1);
        this.layers = this.processLeaves();

        return this;
    }

    public getDefaultRoot(): bigint {
        return this.defaultHashes.slice(-1)[0];
    }

    public getRoot(): bigint {
        const root = this.layers[this.depth][0];
        if (!root) return this.defaultHashes[this.depth];
        return root;
    }

    public getProof(leafIdx: number): bigint[] {
        assert(this.isValidLeafIdx(leafIdx), '[getProof] invalid leaf index');

        const path: bigint[] = [];

        let index = leafIdx;
        for (let layerIdx = 0; layerIdx < this.depth; layerIdx++) {
            const layer = this.layers[layerIdx];
            const isRightNode = index % 2 === 1;
            const pairIdx = isRightNode ? index - 1 : index + 1;

            if (pairIdx < layer.length) {
                path.push(layer[pairIdx]);
            } else {
                path.push(this.defaultHashes[layerIdx]);
            }

            index = Math.floor(index / 2);
        }

        return path;
    }

    public verifyProof(
        leaf: bigint,
        leafIdx: number,
        merklePath: bigint[],
    ): boolean {
        assert(
            this.isValidLeafIdx(leafIdx),
            '[verifyProof] invalid leaf index',
        );

        let currentLeaf: bigint = leaf;
        let index = leafIdx;

        for (let i = 0; i < this.depth; i++) {
            const isRight = index % 2 === 1;
            currentLeaf = this.hash(
                isRight
                    ? [merklePath[i], currentLeaf]
                    : [currentLeaf, merklePath[i]],
            );

            index = Math.floor(index / 2);
        }

        return currentLeaf === this.getRoot();
    }

    public isValidLeafIdx(
        leafIdx: number,
        validNoneZeroNodeIdx = false,
    ): boolean {
        if (validNoneZeroNodeIdx)
            return leafIdx >= 0 && leafIdx < this.leaves.length;

        return leafIdx >= 0 && leafIdx < this.leafCount;
    }

    public isEmpty(): boolean {
        return this.leaves.length === 0;
    }

    public isFull(): boolean {
        return this.leaves.length >= this.leafCount;
    }

    private computeDefaultHashes() {
        const defaultHashes = [this.zeroValue];

        for (let layer = 1; layer <= this.depth; layer++) {
            defaultHashes.push(
                this.hash([defaultHashes[layer - 1], defaultHashes[layer - 1]]),
            );
        }

        return defaultHashes;
    }

    private processLeaves(): bigint[][] {
        const isOdd = this.leaves.length % 2 === 1;
        const leaves = isOdd ? [...this.leaves, this.zeroValue] : this.leaves;
        const layers: bigint[][] = [leaves];

        for (let layer = 1; layer <= this.depth; layer++) {
            const prevLayer = layers[layer - 1];
            const nextLayer = [];

            for (let leaf = 0; leaf < prevLayer.length; leaf += 2) {
                const currentLeaf = prevLayer[leaf];
                const nextLeaf =
                    prevLayer[leaf + 1] || this.defaultHashes[layer - 1];
                nextLayer.push(this.hash([currentLeaf, nextLeaf]));
            }

            layers.push(nextLayer);
        }

        return layers;
    }
}
