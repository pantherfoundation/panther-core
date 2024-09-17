// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation"

//TODO: enable eslint

/* eslint-disable */

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {ensureMinBalance, impersonate} from '../../lib/hardhat';
import {getPoseidonT3Contract} from '../../lib/poseidonBuilder';
import {zeroLeaf} from '../../lib/utilities';
import {PantherPoolV1, PantherTaxiTree} from '../../types/contracts';

import {PantherTaxiMerkleTree} from './helpers/PantherTaxiMerkleTree';
import {randomInputGenerator} from './helpers/randomSnarkFriendlyInputGenerator';

const BigNumber = ethers.BigNumber;
const MAX_LEAF_NUM = 128;

describe.skip('PantherTaxiTree', () => {
    let pantherTaxiTree: PantherTaxiTree;
    let pantherPool: FakeContract<PantherPoolV1>;
    let signer: SignerWithAddress;
    let merkleTree: PantherTaxiMerkleTree;

    beforeEach(async function () {
        const poseidonT3 = await (await getPoseidonT3Contract()).deploy();
        await poseidonT3.deployed();

        pantherPool = await smock.fake('PantherPoolV1');
        signer = await impersonate(pantherPool.address);
        await ensureMinBalance(signer.address, ethers.utils.parseEther('100'));

        const MockpantherTaxiTree = await ethers.getContractFactory(
            'PantherTaxiTree',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                },
            },
        );

        pantherTaxiTree = (await MockpantherTaxiTree.deploy(
            pantherPool.address,
        )) as PantherTaxiTree;

        merkleTree = new PantherTaxiMerkleTree(zeroLeaf);
    });

    it('should update the root', async () => {
        const zeroRoot = BigNumber.from(merkleTree.root).toHexString();
        const root = await pantherTaxiTree.getRoot();

        expect(zeroRoot).to.be.eq(root);
    });

    describe('UTXO insertion', () => {
        it('should insert one utxo and update the root', async () => {
            const utxo = randomInputGenerator();
            merkleTree.insertLeaf(utxo);

            await pantherTaxiTree.connect(signer).addUtxo(utxo);
            expect(BigNumber.from(merkleTree.root).toHexString()).to.be.eq(
                await pantherTaxiTree.getRoot(),
            );
        });

        it('should revert if addUtxo is not called by pantherPool', async () => {
            const utxo = randomInputGenerator();
            merkleTree.insertLeaf(utxo);

            await expect(pantherTaxiTree.addUtxo(utxo)).to.be.revertedWith(
                'ImmOwn: unauthorized',
            );
        });

        it('should insert multiple utxos and update the root', async () => {
            const utxos = Array.from({length: 3}, () => randomInputGenerator());
            utxos.forEach(utxo => merkleTree.insertLeaf(utxo));

            await pantherTaxiTree.connect(signer).addUtxos(utxos);
            expect(BigNumber.from(merkleTree.root).toHexString()).to.be.eq(
                await pantherTaxiTree.getRoot(),
            );
        });

        it('should revert if addUtxos is not called by pantherPool', async () => {
            const utxos = Array.from({length: 3}, () => randomInputGenerator());
            utxos.forEach(utxo => merkleTree.insertLeaf(utxo));

            await expect(pantherTaxiTree.addUtxos(utxos)).to.be.revertedWith(
                'ImmOwn: unauthorized',
            );
        });

        it('should insert a leaf into the right subtree when left is full', async function () {
            await fillSubtree(
                merkleTree,
                pantherTaxiTree,
                signer,
                'left',
                MAX_LEAF_NUM,
            );

            const leaf = randomInputGenerator();
            merkleTree.insertLeaf(leaf);
            await pantherTaxiTree.connect(signer).addUtxo(leaf);

            expect(merkleTree.rightSubtree.leaves[0]).to.be.equal(leaf);
            expect(BigNumber.from(merkleTree.root).toHexString()).to.be.eq(
                await pantherTaxiTree.getRoot(),
            );
        });

        it('should reset the left subtree when full', async function () {
            await fillSubtree(
                merkleTree,
                pantherTaxiTree,
                signer,
                'left',
                MAX_LEAF_NUM,
            );
            const originalRoot = await pantherTaxiTree.getRoot();

            await fillSubtree(
                merkleTree,
                pantherTaxiTree,
                signer,
                'right',
                MAX_LEAF_NUM,
            );

            const newRoot = await pantherTaxiTree.getRoot();
            expect(newRoot).to.not.equal(originalRoot);

            const utxo = randomInputGenerator();
            merkleTree.insertLeaf(utxo);
            await pantherTaxiTree.connect(signer).addUtxo(utxo);

            expect(merkleTree.leftSubtree.leaves.length).to.be.equal(1);
            expect(BigNumber.from(merkleTree.root).toHexString()).to.be.eq(
                await pantherTaxiTree.getRoot(),
            );
        });

        it('should reset the right subtree when the left subtree is full', async function () {
            await fillSubtree(
                merkleTree,
                pantherTaxiTree,
                signer,
                'left',
                MAX_LEAF_NUM,
            );

            await fillSubtree(
                merkleTree,
                pantherTaxiTree,
                signer,
                'right',
                MAX_LEAF_NUM,
            );

            await fillSubtree(
                merkleTree,
                pantherTaxiTree,
                signer,
                'left',
                MAX_LEAF_NUM,
            );

            const utxo = randomInputGenerator();
            merkleTree.insertLeaf(utxo);
            await pantherTaxiTree.connect(signer).addUtxo(utxo);

            expect(merkleTree.rightSubtree.leaves.length).to.be.equal(1);
            expect(BigNumber.from(merkleTree.root).toHexString()).to.be.eq(
                await pantherTaxiTree.getRoot(),
            );
        });

        async function fillSubtree(
            merkleTree: PantherTaxiMerkleTree,
            treeContract: PantherTaxiTree,
            signer: SignerWithAddress,
            subtree: 'left' | 'right',
            numLeaves: number,
        ) {
            for (let i = 0; i < numLeaves; i++) {
                const utxo = randomInputGenerator();
                merkleTree.insertLeaf(utxo);
                await treeContract.connect(signer).addUtxo(utxo);
            }
            expect(merkleTree[`${subtree}Subtree`].leaves.length).to.be.equal(
                numLeaves,
            );
        }
    });
});
