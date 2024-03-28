// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import type {BigNumberish} from 'ethers';
import {BigNumber} from 'ethers';

import {pantherCoreZeroLeaf} from '../utilities';

type ZZone = {
    // ID of the zone currently active
    zoneId: BigNumberish;
    // x-coordinate of the of the Zone Safe operator's pubkey
    edDsaPubKeyX: BigNumberish;
    // y-coordinate of the of the Zone Safe operator's pubkey
    edDsaPubKeyY: BigNumberish;
    // List of allowed origin zones IDs
    originZoneIDs: BigNumberish;
    // List of allowed target zones IDs
    targetZoneIDs: BigNumberish;
    // The bit map of allowed network (bit index is the networkId)
    zZoneNetworkIDsBitMap: BigNumberish;
    // List of allowed KYC/KYT pubkeys and rules (up to 10 elements x 24 bits each)
    zZoneKycKytMerkleTreeLeafIDsAndRulesList: BigNumberish;
    // Period in seconds of KYC attestation validity
    // (120 days)
    zZoneKycExpiryTime: BigNumberish;
    // Period in seconds of KYT attestation validity
    zZoneKytExpiryTime: BigNumberish;
    // Maximum allowed deposit amount
    zZoneDepositMaxAmount: BigNumberish;
    // Maximum allowed withdrawal amount
    zZoneWithrawMaxAmount: BigNumberish;
    // Maximum allowed internal tx amount
    zZoneInternalMaxAmount: BigNumberish;
    // Zone-level List of blacklisted zAccount IDs (10 elements of 24 bits each)
    // The zAccount ID of 0x0FFF can't exist. 24 bits set to "1" in a list
    // element means "no zAccount" is blacklisted. 240 bits set to one means
    zZoneZAccountIDsBlackList: BigNumberish;
    // Limit on the sum of deposits+withdrawals+internal_txs amounts
    // for the period defined further
    zZoneMaximumAmountPerTimePeriod: BigNumberish;
    // Period to count the above limit for
    zZoneTimePeriodPerMaximumAmount: BigNumberish;
};

export const leafs: ZZone[] = [
    {
        zoneId: 1n,
        edDsaPubKeyX:
            13969057660566717294144404716327056489877917779406382026042873403164748884885n,
        edDsaPubKeyY:
            11069452135192839850369824221357904553346382352990372044246668947825855305207n,
        originZoneIDs: 1n, //(the only zone, with zoneId "1", is allowed yet)
        targetZoneIDs: 1n, // (only this zone, with zoneId "1", is allowed yet)
        // Two one-bit flags are set (to "1"):
        // - bit #0 - undefined (reserved for the Ethereum Mainnet)
        // - bit #1 - Goerli (zNetworkId = 1) enabled
        // - bit #2 - Mumbai (zNetworkId = 2) enabled
        zZoneNetworkIDsBitMap: 6n,
        // 2 elements defined:
        // - 1st element, in LS bits 0-23:
        //   - KYC rule ID, 91 ('0b01011011'), in 8 LS bits,
        //   - followed by the provider pubkey leaf index, 0, in next 16 bits
        // - 2nd element, in LS bits 24-47):
        //   - KYT rule ID, 94 ('0b01011110'), in 8 LS bits,
        //   - followed by the provider pubkey leaf index, 0, in next 16 bits
        // This two groups combine in 0b 000000000000000001011110 000000000000000001011011,
        zZoneKycKytMerkleTreeLeafIDsAndRulesList: 1577058395n,
        // 120 days
        zZoneKycExpiryTime: 10368000n,
        // 24 hours
        zZoneKytExpiryTime: 86400n,
        // expressed in the "weighted units"
        zZoneDepositMaxAmount: BigInt(1e12),
        // expressed in the "weighted units"
        zZoneWithrawMaxAmount: BigInt(1e12),
        // expressed in the "weighted units"
        zZoneInternalMaxAmount: BigInt(1e12),
        // "no zAccounts are blacklisted")
        // The value is  240 bits set to 1:
        zZoneZAccountIDsBlackList:
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        // expressed in the "weighted units"
        zZoneMaximumAmountPerTimePeriod: BigInt(1e13),
        // 24 hours
        zZoneTimePeriodPerMaximumAmount: 86400n,
    },
];

export class ZZonesRegistry {
    leafs: ZZone[];
    commitments: string[] = [];
    root: string | null = null;
    zZoneRegistryInsertionInputs: any[] = [];

    levels = 16;

    constructor(leafs: ZZone[]) {
        this.leafs = leafs;
    }

    _getZeroTree() {
        return new MerkleTree(
            poseidon,
            this.levels,
            BigInt(pantherCoreZeroLeaf),
        );
    }

    computeCommitments(): ZZonesRegistry {
        this.commitments = this.leafs.map(leaf =>
            poseidon(Object.values(leaf)),
        );
        return this;
    }

    getInsertionInputs(): ZZonesRegistry {
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

            this.zZoneRegistryInsertionInputs.push({
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
