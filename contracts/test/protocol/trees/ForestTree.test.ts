// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock, FakeContract} from '@defi-wonderland/smock';
import {BigNumberish} from '@ethersproject/bignumber/lib/bignumber';
import type {BytesLike} from '@ethersproject/bytes';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/lib/utils/constants';
import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {fromRpcSig} from 'ethereumjs-util';
import {ContractFactory} from 'ethers';
import {ethers} from 'hardhat';

import {revertSnapshot, takeSnapshot} from '../../../lib/hardhat';
import {
    getPoseidonT3Contract,
    getPoseidonT4Contract,
} from '../../../lib/poseidonBuilder';
import {getBlockNumber, getBlockTimestamp} from '../../../lib/provider';
import {MockForestTree, FeeMaster, TokenMock} from '../../../types/contracts';
import {SnarkProofStruct} from '../../../types/contracts/MockVerifier';
import {randomInputGenerator} from '../helpers/randomSnarkFriendlyInputGenerator';

describe('ForestTree', function () {
    let forestTree: MockForestTree;
    let forestTreeFactory: ContractFactory;
    let zkp: TokenMock;
    let feeMaster: FakeContract<FeeMaster>;

    let owner: SignerWithAddress;
    let miner: SignerWithAddress;
    let utxoInserter: SignerWithAddress;

    let snapshotId: number;

    const miningRewardVersion = 1;

    const reservationRate = 10_00; // 10%
    const premiumRate = 5_00; // 5%
    const minEmptyQueueAge = 0; // 0 blocks
    const onboardingQueueCircuitId = 99; // random uint160

    before(async () => {
        [, owner, miner, utxoInserter] = await ethers.getSigners();

        const PoseidonT4 = await getPoseidonT4Contract();
        const poseidonT4 = await PoseidonT4.deploy();
        await poseidonT4.deployed();

        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        zkp = await (
            await ethers.getContractFactory('TokenMock', owner)
        ).deploy();

        feeMaster = await smock.fake('FeeMaster');

        forestTreeFactory = await ethers.getContractFactory('MockForestTree', {
            libraries: {
                PoseidonT4: poseidonT4.address,
                PoseidonT3: poseidonT3.address,
            },
        });
    });

    beforeEach(async function () {
        snapshotId = await takeSnapshot();

        forestTree = (await forestTreeFactory
            .connect(owner)
            .deploy(
                utxoInserter.address,
                feeMaster.address,
                zkp.address,
                miningRewardVersion,
            )) as MockForestTree;
    });

    afterEach(async () => {
        await revertSnapshot(snapshotId);
    });

    describe('#initializeForestTrees', () => {
        const reservationRate = 10_00; // 10%
        const premiumRate = 5_00; // 5%
        const minEmptyQueueAge = 10; // 10 blocks
        const onboardingQueueCircuitId = 99; // random uint160

        const firstCachedRoot = 0;

        it('should initilize the forest tree', async () => {
            const taxiTreeRoot = await forestTree.getTaxiTreeRoot();
            const busTreeRoot = await forestTree.getBusTreeRoot();
            const ferryTreeRoot = await forestTree.getFerryTreeRoot();
            const blockTime = await getBlockTimestamp();

            const forestRoot = poseidon([
                taxiTreeRoot,
                busTreeRoot,
                ferryTreeRoot,
            ]);

            await expect(
                forestTree
                    .connect(owner)
                    .initializeForestTrees(
                        onboardingQueueCircuitId,
                        reservationRate,
                        premiumRate,
                        minEmptyQueueAge,
                    ),
            )
                .to.emit(forestTree, 'ForestRootInitialized')
                .withArgs(forestRoot, firstCachedRoot)
                .and.to.emit(forestTree, 'BusTreeInitialized')
                .withArgs(blockTime + 1)
                .and.to.emit(forestTree, 'BusQueueRewardParamsUpdated')
                .withArgs(reservationRate, premiumRate, minEmptyQueueAge)
                .and.to.emit(forestTree, 'CircuitIdUpdated')
                .withArgs(onboardingQueueCircuitId);

            expect((await forestTree.getRoots())._forestRoot).to.be.eq(
                forestRoot,
            );
        });

        it('should not be initilized twice', async () => {
            await forestTree
                .connect(owner)
                .initializeForestTrees(
                    onboardingQueueCircuitId,
                    reservationRate,
                    premiumRate,
                    minEmptyQueueAge,
                );

            await expect(
                forestTree
                    .connect(owner)
                    .initializeForestTrees(
                        onboardingQueueCircuitId,
                        reservationRate,
                        premiumRate,
                        minEmptyQueueAge,
                    ),
            ).to.revertedWith('FT: Already initialized');
        });

        it('should not be initilized by non-owner', async () => {
            await expect(
                forestTree
                    .connect(miner)
                    .initializeForestTrees(
                        onboardingQueueCircuitId,
                        reservationRate,
                        premiumRate,
                        minEmptyQueueAge,
                    ),
            ).to.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('#addUtxosToBusQueue and #addUtxosToBusQueueAndTaxiTree', () => {
        const cachedForestRootIndex = 0;
        const reward = 1;
        const firstBusQueueId = 0;

        let utxos: BytesLike[];
        let roots: {
            _staticRoot: string;
            _forestRoot: string;
        };

        beforeEach(async () => {
            await forestTree
                .connect(owner)
                .initializeForestTrees(
                    onboardingQueueCircuitId,
                    reservationRate,
                    premiumRate,
                    minEmptyQueueAge,
                );

            utxos = [
                randomInputGenerator(),
                randomInputGenerator(),
                randomInputGenerator(),
                randomInputGenerator(),
                randomInputGenerator(),
                randomInputGenerator(),
            ];
            roots = await forestTree.getRoots();
        });

        describe('#addUtxosToBusQueue', () => {
            it('should add utxos to bus queue', async () => {
                await expect(
                    forestTree
                        .connect(utxoInserter)
                        .addUtxosToBusQueue(
                            utxos,
                            cachedForestRootIndex,
                            roots._forestRoot,
                            roots._staticRoot,
                            reward,
                        ),
                )
                    .to.emit(forestTree, 'BusQueueOpened')
                    .withArgs(firstBusQueueId);
            });

            it('should not add utxos by random user', async () => {
                await expect(
                    forestTree
                        .connect(owner)
                        .addUtxosToBusQueue(
                            utxos,
                            cachedForestRootIndex,
                            roots._forestRoot,
                            roots._staticRoot,
                            reward,
                        ),
                ).to.revertedWith('pantherTrees: unauthorized panther pool');
            });

            it('should not add empty utxos', async () => {
                await expect(
                    forestTree
                        .connect(utxoInserter)
                        .addUtxosToBusQueue(
                            [],
                            cachedForestRootIndex,
                            roots._forestRoot,
                            roots._staticRoot,
                            reward,
                        ),
                ).to.revertedWith('FT: empty utxos');
            });

            it('should not add utxos with wrong forest tree root', async () => {
                await expect(
                    forestTree
                        .connect(utxoInserter)
                        .addUtxosToBusQueue(
                            utxos,
                            cachedForestRootIndex,
                            randomInputGenerator(),
                            roots._staticRoot,
                            reward,
                        ),
                ).to.revertedWith('FT: invalid roots');

                await expect(
                    forestTree
                        .connect(utxoInserter)
                        .addUtxosToBusQueue(
                            utxos,
                            cachedForestRootIndex,
                            roots._forestRoot,
                            randomInputGenerator(),
                            reward,
                        ),
                ).to.revertedWith('FT: invalid roots');
            });
        });

        describe('#addUtxosToBusQueueAndTaxiTree', () => {
            it('should add the first utxo from the utxos array to the taxi tree', async () => {
                const numTaxiUtxos = 1;
                const totalLeavesInsertions = 1;

                await expect(
                    forestTree
                        .connect(utxoInserter)
                        .addUtxosToBusQueueAndTaxiTree(
                            utxos,
                            numTaxiUtxos,
                            cachedForestRootIndex,
                            roots._forestRoot,
                            roots._staticRoot,
                            reward,
                        ),
                )
                    .to.emit(forestTree, 'TaxiUtxoAdded')
                    .withArgs(utxos[0], totalLeavesInsertions);
            });

            it('should add the first 3 utxos from the utxos array to the taxi tree', async () => {
                const numTaxiUtxos = 3;

                await expect(
                    forestTree
                        .connect(utxoInserter)
                        .addUtxosToBusQueueAndTaxiTree(
                            utxos,
                            numTaxiUtxos,
                            cachedForestRootIndex,
                            roots._forestRoot,
                            roots._staticRoot,
                            reward,
                        ),
                )
                    .to.emit(forestTree, 'TaxiUtxoAdded')
                    .withArgs(utxos[0], 1)
                    .and.to.emit(forestTree, 'TaxiUtxoAdded')
                    .withArgs(utxos[1], 2)
                    .and.to.emit(forestTree, 'TaxiUtxoAdded')
                    .withArgs(utxos[2], 3);
            });
        });
    });

    describe('#onboardBusQueue', () => {
        const proof: SnarkProofStruct = {
            a: {x: 1, y: 2},
            b: {x: [1, 2], y: [3, 4]},
            c: {x: 5, y: 6},
        };

        const miningReward = ethers.utils.parseEther('10');
        const cachedForestRootIndex = 0;
        const firstBusQueueId = 0;

        const newBusTreeRoot = randomInputGenerator();
        const branchRoot = randomInputGenerator();
        const batchRoot = randomInputGenerator();
        const magicalConstraint = randomInputGenerator();
        const inputs: BigNumberish[] = [];
        let extraInputHash: BigNumberish;
        let oldBusTreeRoot: BigNumberish;
        let newLeafsCommitment: BigNumberish;
        let replacedNodeIndex: BigNumberish;
        let nNonEmptyNewLeafs: BigNumberish;

        beforeEach(async () => {
            await forestTree
                .connect(owner)
                .initializeForestTrees(
                    onboardingQueueCircuitId,
                    reservationRate,
                    premiumRate,
                    minEmptyQueueAge,
                );

            const roots = await forestTree.getRoots();
            const utxos = [
                randomInputGenerator(),
                randomInputGenerator(),
                randomInputGenerator(),
            ];

            await forestTree
                .connect(utxoInserter)
                .addUtxosToBusQueue(
                    utxos,
                    cachedForestRootIndex,
                    roots._forestRoot,
                    roots._staticRoot,
                    miningReward,
                );

            const extraInput = ethers.utils.solidityPack(
                ['address', 'uint32'],
                [miner.address, firstBusQueueId],
            );
            extraInputHash = ethers.BigNumber.from(
                ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
            ).mod(SNARK_FIELD_SIZE);

            oldBusTreeRoot = await forestTree.getBusTreeRoot();
            newLeafsCommitment = (await forestTree.getBusQueue(firstBusQueueId))
                .commitment;
            replacedNodeIndex = 0;
            nNonEmptyNewLeafs = utxos.length;

            inputs[0] = oldBusTreeRoot;
            inputs[1] = newBusTreeRoot;
            inputs[2] = replacedNodeIndex;
            inputs[3] = newLeafsCommitment;
            inputs[4] = nNonEmptyNewLeafs;
            inputs[5] = batchRoot;
            inputs[6] = branchRoot;
            inputs[7] = extraInputHash;
            inputs[8] = magicalConstraint;
        });

        it('should onboard bus queue', async () => {
            const busTreeLeafIndex = 1;
            const cacheRootIndex = 1;

            const minerRewardContribution = miningReward
                .mul(premiumRate)
                .div(100_00);

            const expectedMiningReward = miningReward.sub(
                minerRewardContribution,
            );

            await expect(
                forestTree.onboardBusQueue(
                    miner.address,
                    firstBusQueueId,
                    inputs,
                    proof,
                ),
            )
                .to.emit(forestTree, 'ForestRootUpdated')
                .withArgs(
                    busTreeLeafIndex,
                    await forestTree.getBusTreeRoot(),
                    (await forestTree.getRoots())._forestRoot,
                    cacheRootIndex,
                )
                .and.to.emit(forestTree, 'MinerRewardAccounted')
                .withArgs(firstBusQueueId, miner.address, expectedMiningReward);

            expect(await forestTree.miningRewards(miner.address)).to.be.eq(
                expectedMiningReward,
            );
        });
    });

    describe('#claimMinerRewards', () => {
        const miningReward = ethers.utils.parseEther('10');

        beforeEach(async () => {
            await forestTree.mockSetMiningRewards(miner.address, miningReward);
        });

        it('should claim rewards by miner', async () => {
            const blockNumber = await getBlockNumber();

            await expect(
                forestTree.connect(miner).claimMiningReward(miner.address),
            )
                .to.emit(forestTree, 'MinerRewardClaimed')
                .withArgs(blockNumber + 1, miner.address, miningReward);
        });

        it('should claim rewards by signature', async () => {
            const name = 'Panther Protocol';
            const version = '1';
            const chainId = (await ethers.provider.getNetwork()).chainId;
            const salt: BytesLike =
                '0x44b818e3e3a12ecf805989195d8f38e75517386006719e2dbb1443987a34db7b';
            const verifyingContract = forestTree.address;

            const types = {
                ClaimMiningReward: [
                    {name: 'receiver', type: 'address'},
                    {name: 'version', type: 'uint256'},
                ],
            };

            const value = {
                receiver: miner.address,
                version: miningRewardVersion,
            };
            const domain = {
                name,
                version,
                chainId,
                verifyingContract,
                salt,
            };

            const signature = await miner._signTypedData(domain, types, value);
            const {v, r, s} = fromRpcSig(signature); // does nothing other that splitting the signature string

            const blockNumber = await getBlockNumber();

            await expect(
                forestTree
                    .connect(miner)
                    .claimMiningRewardWithSignature(miner.address, v, r, s),
            )
                .to.emit(forestTree, 'MinerRewardClaimed')
                .withArgs(blockNumber + 1, miner.address, miningReward);
        });
    });
});
