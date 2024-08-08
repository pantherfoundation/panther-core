// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation"

import {MerkleTree} from '@zk-kit/merkle-tree';
import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {ethers} from 'hardhat';

import {getPoseidonT3Contract} from '../../lib/poseidonBuilder';
import {zeroLeaf} from '../../lib/utilities';
import {PantherTaxiTree} from '../../types/contracts';

import {randomInputGenerator} from './helpers/randomSnarkFriendlyInputGenerator';

const BigNumber = ethers.BigNumber;

describe.skip('PantherTaxiTree', () => {
    let pantherTaxiTree: PantherTaxiTree;

    before(async () => {
        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        const MockpantherTaxiTree = await ethers.getContractFactory(
            'MockpantherTaxiTree',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                },
            },
        );

        pantherTaxiTree =
            (await MockpantherTaxiTree.deploy()) as PantherTaxiTree;
    });

    it('should update the root', async () => {
        const taxiTree = new MerkleTree(poseidon, 8, zeroLeaf);
        const zeroRoot = BigNumber.from(taxiTree.root).toHexString();

        const root = await pantherTaxiTree.getTaxiTreeRoot();

        expect(zeroRoot).to.be.eq(root);
    });

    describe('UTXO insertion', () => {
        let oneUtxo: string;
        let threeUtxos: string[];
        let merkleTree: MerkleTree;

        beforeEach(async () => {
            oneUtxo = randomInputGenerator();
            threeUtxos = [
                randomInputGenerator(),
                randomInputGenerator(),
                randomInputGenerator(),
            ];

            merkleTree = new MerkleTree(poseidon, 8, zeroLeaf);
        });

        it('should insert one utxo', async () => {
            merkleTree.insert(oneUtxo);

            const newMerkleTreeRoot = ethers.utils.hexZeroPad(
                merkleTree.root,
                32,
            );

            await pantherTaxiTree.addUtxo(oneUtxo);
            const newTaxiTreeRoot = await pantherTaxiTree.getTaxiTreeRoot();

            expect(newMerkleTreeRoot).to.be.eq(newTaxiTreeRoot);
        });

        it('should update the root when inserting 3 leaves', async () => {
            for (let i = 0; i < threeUtxos.length; i++) {
                merkleTree.insert(threeUtxos[i]);
            }

            const newMerkleTreeRoot = ethers.utils.hexZeroPad(
                merkleTree.root,
                32,
            );

            await pantherTaxiTree.addThreeUtxos(
                threeUtxos[0],
                threeUtxos[1],
                threeUtxos[2],
            );
            const newTaxiTreeRoot = await pantherTaxiTree.getTaxiTreeRoot();

            expect(newMerkleTreeRoot).to.be.eq(newTaxiTreeRoot);
        });
    });
});
