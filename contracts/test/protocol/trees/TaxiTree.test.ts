// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {ethers} from 'hardhat';

import {PantherTaxiMerkleTree} from '.././helpers/PantherTaxiMerkleTree';
import {randomInputGenerator} from '.././helpers/randomSnarkFriendlyInputGenerator';
import {getPoseidonT3Contract} from '../../../lib/poseidonBuilder';
import {zeroLeaf} from '../../../lib/utilities';
import {MockTaxiTree} from '../../../types/contracts';

const BigNumber = ethers.BigNumber;
const MAX_LEAF_NUM = 128;

describe('TaxiTree', () => {
    let taxiTree: MockTaxiTree;
    let merkleTree: PantherTaxiMerkleTree;

    beforeEach(async function () {
        const poseidonT3 = await (await getPoseidonT3Contract()).deploy();
        await poseidonT3.deployed();

        const MockTaxiTree = await ethers.getContractFactory('MockTaxiTree', {
            libraries: {
                PoseidonT3: poseidonT3.address,
            },
        });

        taxiTree = (await MockTaxiTree.deploy()) as MockTaxiTree;

        merkleTree = new PantherTaxiMerkleTree(zeroLeaf);
    });

    it('should update the root', async () => {
        const zeroRoot = BigNumber.from(merkleTree.root).toHexString();
        const root = await taxiTree.getTaxiTreeRoot();

        expect(zeroRoot).to.be.eq(root);
    });

    describe('UTXO insertion', () => {
        it('should insert one utxo and update the root', async () => {
            const utxo = randomInputGenerator();
            merkleTree.insertLeaf(utxo);

            await taxiTree.addUtxo(utxo);

            const actualRoot = await taxiTree.getTaxiTreeRoot();
            const expectedRoot = ethers.utils.hexZeroPad(
                BigNumber.from(merkleTree.root),
                32,
            );
            await expect(actualRoot).to.be.equal(expectedRoot);
        });

        it('should insert multiple utxos and update the root', async () => {
            const utxos = Array.from({length: 3}, () => randomInputGenerator());
            utxos.forEach(utxo => merkleTree.insertLeaf(utxo));

            await taxiTree.addUtxos(utxos);

            const actualRoot = await taxiTree.getTaxiTreeRoot();
            const expectedRoot = ethers.utils.hexZeroPad(
                BigNumber.from(merkleTree.root),
                32,
            );
            await expect(actualRoot).to.be.equal(expectedRoot);
        });

        it('should insert a leaf into the right subtree when left is full', async function () {
            await fillSubtree(merkleTree, taxiTree, 'left', MAX_LEAF_NUM);

            const leaf = randomInputGenerator();
            merkleTree.insertLeaf(leaf);
            await taxiTree.addUtxo(leaf);

            expect(merkleTree.rightSubtree.leaves[0]).to.be.equal(leaf);

            const actualRoot = await taxiTree.getTaxiTreeRoot();
            const expectedRoot = ethers.utils.hexZeroPad(
                BigNumber.from(merkleTree.root),
                32,
            );
            await expect(actualRoot).to.be.equal(expectedRoot);
        });

        it('should reset the left subtree when full', async function () {
            await fillSubtree(merkleTree, taxiTree, 'left', MAX_LEAF_NUM);
            const originalRoot = await taxiTree.getTaxiTreeRoot();

            await fillSubtree(merkleTree, taxiTree, 'right', MAX_LEAF_NUM);

            const newRoot = await taxiTree.getTaxiTreeRoot();
            expect(newRoot).to.not.equal(originalRoot);

            const utxo = randomInputGenerator();
            merkleTree.insertLeaf(utxo);
            await taxiTree.addUtxo(utxo);

            expect(merkleTree.leftSubtree.leaves.length).to.be.equal(1);

            const actualRoot = await taxiTree.getTaxiTreeRoot();
            const expectedRoot = ethers.utils.hexZeroPad(
                BigNumber.from(merkleTree.root),
                32,
            );
            await expect(actualRoot).to.be.equal(expectedRoot);
        });

        it('should reset the right subtree when the left subtree is full', async function () {
            await fillSubtree(merkleTree, taxiTree, 'left', MAX_LEAF_NUM);

            await fillSubtree(merkleTree, taxiTree, 'right', MAX_LEAF_NUM);

            await fillSubtree(merkleTree, taxiTree, 'left', MAX_LEAF_NUM);

            const utxo = randomInputGenerator();
            merkleTree.insertLeaf(utxo);
            await taxiTree.addUtxo(utxo);

            expect(merkleTree.rightSubtree.leaves.length).to.be.equal(1);

            const actualRoot = await taxiTree.getTaxiTreeRoot();
            const expectedRoot = ethers.utils.hexZeroPad(
                BigNumber.from(merkleTree.root),
                32,
            );
            await expect(actualRoot).to.be.equal(expectedRoot);
        });

        async function fillSubtree(
            merkleTree: PantherTaxiMerkleTree,
            treeContract: MockTaxiTree,
            subtree: 'left' | 'right',
            numLeaves: number,
        ) {
            for (let i = 0; i < numLeaves; i++) {
                const utxo = randomInputGenerator();
                merkleTree.insertLeaf(utxo);
                await treeContract.addUtxo(utxo);
            }
            expect(merkleTree[`${subtree}Subtree`].leaves.length).to.be.equal(
                numLeaves,
            );
        }
    });
});
