// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber} from 'ethers';

import {pantherCoreZeroLeaf} from '../utilities';

type ZNetwork = {
    active: BigNumberish;
    chainId: BigNumberish;
    networkId: BigNumberish;
    // One-bit flags enabling creating/spending on this network UTXOs spendable/created on
    // other networks; LS bit for the network with ID 0, followed by the bit for the ID 1, ...)
    networkIDsBitMap: BigNumberish;
    forTxReward: BigNumberish;
    forUtxoReward: BigNumberish;
    forDepositReward: BigNumberish;
    daoDataEscrowPubKeyX: BigNumberish;
    daoDataEscrowPubKeyY: BigNumberish;
};
export const localLeafs: {[key: string]: ZNetwork} = {
    localhost: {
        active: 1n,
        chainId: 31337n,
        networkId: 0n,
        // (network with ID 0 is enabled)
        networkIDsBitMap: 1n,
        forTxReward: 10n,
        forUtxoReward: 1828n,
        forDepositReward: 57646075n,
        daoDataEscrowPubKeyX:
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        daoDataEscrowPubKeyY:
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
    },
};

export const testnetLeafs: {[key: string]: ZNetwork} = {
    reserved: {
        active: 1n,
        chainId: 1n,
        networkId: 1n,
        // (networks with IDs 1 and 2 are enabled)
        networkIDsBitMap: 6n,
        forTxReward: 10n,
        forUtxoReward: 1828n,
        forDepositReward: 57646075n,
        daoDataEscrowPubKeyX:
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        daoDataEscrowPubKeyY:
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
    },
    sepoila: {
        active: 1n,
        chainId: 11155111n,
        networkId: 2n,
        // (networks with IDs 1 and 2 are enabled)
        networkIDsBitMap: 6n,
        forTxReward: 10n,
        forUtxoReward: 1828n,
        forDepositReward: 57646075n,
        daoDataEscrowPubKeyX:
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        daoDataEscrowPubKeyY:
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
    },
};

export class ZNetworksRegistry {
    leafs: ZNetwork[];
    commitments: string[] = [];
    root: string | null = null;
    zNetworkRegistryInsertionInputs: any[] = [];

    levels = 6;

    constructor(leafs: ZNetwork[]) {
        this.leafs = leafs;
    }

    _getZeroTree() {
        return new MerkleTree(
            poseidon,
            this.levels,
            BigInt(pantherCoreZeroLeaf),
        );
    }

    computeCommitments(): ZNetworksRegistry {
        this.commitments = this.leafs.map(leaf =>
            poseidon(Object.values(leaf)),
        );
        return this;
    }

    getInsertionInputs(): ZNetworksRegistry {
        const merkleTree = this._getZeroTree();
        this.computeCommitments();

        this.commitments.forEach((commitment: string, index: number) => {
            const currentRoot = BigNumber.from(merkleTree.root).toHexString();
            const currentLeaf =
                BigNumber.from(pantherCoreZeroLeaf).toHexString();
            const newLeaf = BigNumber.from(commitment).toHexString();
            const leafIndex = BigNumber.from(index).toHexString();

            merkleTree.insert(commitment);
            const proofSiblings = merkleTree
                .createProof(index)
                .siblingNodes.map(x => BigNumber.from(x).toHexString());

            this.zNetworkRegistryInsertionInputs.push({
                currentRoot,
                currentLeaf,
                newLeaf,
                leafIndex,
                proofSiblings,
            });
        });

        this.root = BigNumber.from(merkleTree.root).toHexString();

        return this;
    }
}
