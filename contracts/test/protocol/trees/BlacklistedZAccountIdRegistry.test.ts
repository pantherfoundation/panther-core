// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {BigNumberish} from '@ethersproject/bignumber/lib/bignumber';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {MerkleTree, Proof} from '@zk-kit/merkle-tree';
import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {getPoseidonT3Contract} from '../../../lib/poseidonBuilder';
import {
    MockBlacklistedZAccountsIdsRegistry,
    StaticTree,
} from '../../../types/contracts';

describe.skip('BlacklistedZAccountIdRegistry', () => {
    let blacklistedZAccountsIdsRegistry: MockBlacklistedZAccountsIdsRegistry;
    let staticTree: FakeContract<StaticTree>;
    let pantherPool: SignerWithAddress;

    const treeLevels = 16;

    before(async () => {
        [, pantherPool] = await ethers.getSigners();

        staticTree = await smock.fake('StaticTree');

        const poseidonT3 = await (await getPoseidonT3Contract()).deploy();
        await poseidonT3.deployed();

        const BlacklistedZAccountsIdsRegistry = await ethers.getContractFactory(
            'MockBlacklistedZAccountsIdsRegistry',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                },
            },
        );

        blacklistedZAccountsIdsRegistry =
            (await BlacklistedZAccountsIdsRegistry.deploy(
                staticTree.address,
                pantherPool.address,
            )) as MockBlacklistedZAccountsIdsRegistry;

        // mock static tree
        staticTree.updateStaticRoot.returns();
    });

    describe('_getZAccountFlagAndLeafIndexes', () => {
        const checkFlagIndexAndLeafIndex = async (
            zAccountId: string,
            expectedFlagIndex: string,
            expectedLeafIndex: string,
        ) => {
            const {flagIndex, leafIndex} =
                await blacklistedZAccountsIdsRegistry.internalGetZAccountFlagAndLeafIndexes(
                    zAccountId,
                );

            expect(flagIndex).to.be.eq(expectedFlagIndex);
            expect(leafIndex).to.be.eq(expectedLeafIndex);
        };

        describe('getting zAccount flag and leaf index', () => {
            let zAccountId: string,
                expectedFlagIndex: string,
                expectedLeafIndex: string;

            describe('when zAccount id is between 0 and 253', () => {
                it('should return 0 flag and 0 leaf index', async () => {
                    zAccountId = '0';
                    expectedFlagIndex = '0';
                    expectedLeafIndex = '0';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 1 flag and 0 leaf index', async () => {
                    zAccountId = '1';
                    expectedFlagIndex = '1';
                    expectedLeafIndex = '0';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 2 flag and 0 leaf index', async () => {
                    zAccountId = '2';
                    expectedFlagIndex = '2';
                    expectedLeafIndex = '0';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 3 flag and 0 leaf index', async () => {
                    zAccountId = '3';
                    expectedFlagIndex = '3';
                    expectedLeafIndex = '0';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 4 flag and 0 leaf index', async () => {
                    zAccountId = '4';
                    expectedFlagIndex = '4';
                    expectedLeafIndex = '0';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 253 flag and 0 leaf index', async () => {
                    zAccountId = '253';
                    expectedFlagIndex = '253';
                    expectedLeafIndex = '0';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should revert when zAccount id is 254', async () => {
                    zAccountId = '254';

                    await expect(
                        blacklistedZAccountsIdsRegistry.internalGetZAccountFlagAndLeafIndexes(
                            zAccountId,
                        ),
                    ).to.revertedWith('ZAR:E9');
                });

                it('should revert when zAccount id is 255', async () => {
                    zAccountId = '255';

                    await expect(
                        blacklistedZAccountsIdsRegistry.internalGetZAccountFlagAndLeafIndexes(
                            zAccountId,
                        ),
                    ).to.revertedWith('ZAR:E9');
                });
            });

            describe('when zAccount id is between 256 and 509', () => {
                it('should return 0 flag and 1 leaf index', async () => {
                    zAccountId = '256';
                    expectedFlagIndex = '0';
                    expectedLeafIndex = '1';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 1 flag and 1 leaf index', async () => {
                    zAccountId = '257';
                    expectedFlagIndex = '1';
                    expectedLeafIndex = '1';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 2 flag and 1 leaf index', async () => {
                    zAccountId = '258';
                    expectedFlagIndex = '2';
                    expectedLeafIndex = '1';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 3 flag and 1 leaf index', async () => {
                    zAccountId = '259';
                    expectedFlagIndex = '3';
                    expectedLeafIndex = '1';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 4 flag and 1 leaf index', async () => {
                    zAccountId = '260';
                    expectedFlagIndex = '4';
                    expectedLeafIndex = '1';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should return 253 flag and 1 leaf index', async () => {
                    zAccountId = '509';
                    expectedFlagIndex = '253';
                    expectedLeafIndex = '1';

                    await checkFlagIndexAndLeafIndex(
                        zAccountId,
                        expectedFlagIndex,
                        expectedLeafIndex,
                    );
                });

                it('should revert when zAccount id is 510', async () => {
                    zAccountId = '510';

                    await expect(
                        blacklistedZAccountsIdsRegistry.internalGetZAccountFlagAndLeafIndexes(
                            zAccountId,
                        ),
                    ).to.revertedWith('ZAR:E9');
                });

                it('should revert when zAccount id is 511', async () => {
                    zAccountId = '511';

                    await expect(
                        blacklistedZAccountsIdsRegistry.internalGetZAccountFlagAndLeafIndexes(
                            zAccountId,
                        ),
                    ).to.revertedWith('ZAR:E9');
                });
            });
        });
    });

    describe('addZAccountIdToBlacklist and removeZAccountIdFromBlacklist', () => {
        let zAccountId: BigNumberish;
        let flagIndex: BigNumberish;
        let currentLeaf: BigNumberish;
        let merkleTree: MerkleTree;
        let proof: Proof;

        let leafWithIndex0: BigNumberish;
        let leafWithIndex1: BigNumberish;

        const zeroLeaf = ethers.constants.HashZero;

        beforeEach(() => {
            merkleTree = new MerkleTree(poseidon, treeLevels, zeroLeaf);
        });

        describe('Adding to blacklist', () => {
            const addIdToLeaf = (leaf: BigNumberish, flagIndex: string) => {
                return BigNumber.from(1).shl(+flagIndex).add(leaf).toString();
            };

            const addZAccountIdToBlacklistAndCheckNewRoot = async (
                zAccountId: BigNumberish,
                currentLeaf: BigNumberish,
                proofSiblings: string[],
                expectedRoot: BigNumberish,
            ) => {
                await blacklistedZAccountsIdsRegistry
                    .connect(pantherPool)
                    .addZAccountIdToBlacklist(
                        zAccountId,
                        ethers.utils.hexZeroPad(
                            BigNumber.from(currentLeaf),
                            32,
                        ),
                        proofSiblings.map((x: string) =>
                            ethers.utils.hexZeroPad(BigNumber.from(x), 32),
                        ),
                    );

                expect(
                    await blacklistedZAccountsIdsRegistry.getBlacklistedZAccountsRoot(),
                ).to.be.eq(BigNumber.from(expectedRoot).toHexString());
            };

            describe('adding ids 0 to 253 to the first leaf', () => {
                const leafIndex = 0;

                it('should blacklist zAccount with id 0', async () => {
                    zAccountId = '0';
                    flagIndex = '0';

                    currentLeaf = zeroLeaf;
                    leafWithIndex0 = addIdToLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex0);
                    proof = merkleTree.createProof(leafIndex);

                    await addZAccountIdToBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });

                it('should blacklist zAccount with id 1', async () => {
                    zAccountId = '1';
                    flagIndex = '1';

                    currentLeaf = leafWithIndex0; // 1
                    leafWithIndex0 = addIdToLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex0);
                    proof = merkleTree.createProof(leafIndex);

                    await addZAccountIdToBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });

                it('should blacklist zAccount with id 2', async () => {
                    zAccountId = '2';
                    flagIndex = '2';

                    currentLeaf = leafWithIndex0; // 3
                    leafWithIndex0 = addIdToLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex0);
                    proof = merkleTree.createProof(leafIndex);

                    await addZAccountIdToBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });

                it('should blacklist zAccount with id 3', async () => {
                    zAccountId = '3';
                    flagIndex = '3';

                    currentLeaf = leafWithIndex0; // 7
                    leafWithIndex0 = addIdToLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex0);
                    proof = merkleTree.createProof(leafIndex);

                    await addZAccountIdToBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });

                it('should blacklist zAccount with id 253', async () => {
                    zAccountId = '253';
                    flagIndex = '253';

                    currentLeaf = leafWithIndex0; // 15
                    leafWithIndex0 = addIdToLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex0);
                    proof = merkleTree.createProof(leafIndex);

                    await addZAccountIdToBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });
            });

            describe('adding ids 256 to 509 to the second leaf', () => {
                const leafIndex = 1;
                let proof: Proof;

                beforeEach(() => {
                    merkleTree.insert(leafWithIndex0);
                });

                it('should blacklist zAccount with id 256', async () => {
                    zAccountId = '256';
                    flagIndex = '0';

                    currentLeaf = zeroLeaf;
                    leafWithIndex1 = addIdToLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex1);
                    proof = merkleTree.createProof(leafIndex);

                    await addZAccountIdToBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });

                it('should blacklist zAccount with id 509', async () => {
                    zAccountId = '509';
                    flagIndex = '253';

                    currentLeaf = leafWithIndex1;
                    leafWithIndex1 = addIdToLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex1);
                    proof = merkleTree.createProof(leafIndex);

                    await addZAccountIdToBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });
            });
        });

        describe('Removing from blacklist', () => {
            const removeIdFromLeaf = (
                leaf: BigNumberish,
                flagIndex: string,
            ) => {
                return BigNumber.from(leaf)
                    .xor(BigNumber.from(1).shl(+flagIndex))
                    .toString();
            };

            const removeZAccountIdFromBlacklistAndCheckNewRoot = async (
                zAccountId: BigNumberish,
                currentLeaf: BigNumberish,
                proofSiblings: string[],
                expectedRoot: BigNumberish,
            ) => {
                await blacklistedZAccountsIdsRegistry
                    .connect(pantherPool)
                    .removeZAccountIdFromBlacklist(
                        zAccountId,
                        ethers.utils.hexZeroPad(
                            BigNumber.from(currentLeaf),
                            32,
                        ),
                        proofSiblings.map((x: string) =>
                            ethers.utils.hexZeroPad(BigNumber.from(x), 32),
                        ),
                    );

                expect(
                    await blacklistedZAccountsIdsRegistry.getBlacklistedZAccountsRoot(),
                ).to.be.eq(BigNumber.from(expectedRoot).toHexString());
            };

            describe('removing ids from the first leaf', () => {
                const leafIndex = 0;

                it('should whitelist zAccount with id 0', async () => {
                    zAccountId = '0';
                    flagIndex = '0';

                    currentLeaf = leafWithIndex0;
                    leafWithIndex0 = removeIdFromLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex0);
                    merkleTree.insert(leafWithIndex1);
                    proof = merkleTree.createProof(leafIndex);

                    await removeZAccountIdFromBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });
            });

            describe('removing ids from the second leaf', () => {
                const leafIndex = 1;

                it('should whitelist zAccount with id 509', async () => {
                    zAccountId = '509';
                    flagIndex = '253';

                    currentLeaf = leafWithIndex1;
                    leafWithIndex1 = removeIdFromLeaf(currentLeaf, flagIndex);

                    merkleTree.insert(leafWithIndex0);
                    merkleTree.insert(leafWithIndex1);
                    proof = merkleTree.createProof(leafIndex);

                    await removeZAccountIdFromBlacklistAndCheckNewRoot(
                        zAccountId,
                        currentLeaf,
                        proof.siblingNodes,
                        proof.root,
                    );
                });
            });
        });
    });
});
