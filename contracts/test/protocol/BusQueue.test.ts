// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {MerkleTree} from '@zk-kit/merkle-tree';
import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {ethers} from 'hardhat';

import {getPoseidonT3Contract} from '../../lib/poseidonBuilder';
import {zeroLeaf} from '../../lib/utilities';
import {MockBusQueues} from '../../types/contracts';
import {BusQueues} from '../../types/contracts/MockBusQueues';

import {randomInputGenerator} from './helpers/randomSnarkFriendlyInputGenerator';
import {BigNumber, BigNumberish, ContractFactory} from 'ethers';
import {mineBlock} from '../../lib/hardhat';
import {getBlockNumber} from '../../lib/provider';

const BigNumber = ethers.BigNumber;

describe.only('BusQueue contract', function () {
    let busQueueFactory: ContractFactory;
    let busQueues: MockBusQueues;

    const hundredPercent = 100_00;
    const maxQueueSize = 64;

    before(async () => {
        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        busQueueFactory = await ethers.getContractFactory('MockBusQueues', {
            libraries: {
                PoseidonT3: poseidonT3.address,
            },
        });
    });

    async function getNewBusQueuesInstance(): Promise<MockBusQueues> {
        return (await busQueueFactory.deploy()) as MockBusQueues;
    }

    async function updateBusQueueRewardParams(
        busQueues: MockBusQueues,
        params: {
            reservationRate: number;
            premiumRate: number;
            minEmptyQueueAge: number;
        },
    ) {
        const {reservationRate, premiumRate, minEmptyQueueAge} = params;

        await expect(
            busQueues.internalUpdateBusQueueRewardParams(
                reservationRate,
                premiumRate,
                minEmptyQueueAge,
            ),
        )
            .to.emit(busQueues, 'BusQueueRewardParamsUpdated')
            .withArgs(reservationRate, premiumRate, minEmptyQueueAge);
    }

    function generateQueue(params: {
        [key: string]: BigNumberish;
    }): BusQueues.BusQueueStruct {
        const queue: any = {
            nUtxos: 0,
            reward: 0,
            firstUtxoBlock: 0,
            lastUtxoBlock: 0,
            prevLink: 0,
            nextLink: 0,
        };

        for (const param in params) {
            queue[param] = params[param];
        }

        return queue as BusQueues.BusQueueStruct;
    }

    describe('_updateBusQueueRewardParams', () => {
        this.beforeEach(async () => {
            busQueues = await getNewBusQueuesInstance();
        });

        describe('Success', () => {
            const _reservationRate = 10_00; // 10%
            const _premiumRate = 5_00; // 5%
            const _minEmptyQueueAge = 10; // 10 blocks

            it('updates the bus queue parameters', async () => {
                await updateBusQueueRewardParams(busQueues, {
                    reservationRate: _reservationRate,
                    premiumRate: _premiumRate,
                    minEmptyQueueAge: _minEmptyQueueAge,
                });

                const {reservationRate, premiumRate, minEmptyQueueAge} =
                    await busQueues.getParams();

                expect(reservationRate).to.be.eq(_reservationRate);
                expect(premiumRate).to.be.eq(_premiumRate);
                expect(minEmptyQueueAge).to.be.eq(_minEmptyQueueAge);
            });
        });

        describe('Failure', () => {
            it('reverts is rates are invalid', async () => {
                const reservationRate = 101_00, // 101%
                    premiumRate = 101_00, // 101%
                    minEmptyQueueAge = 0;

                await expect(
                    busQueues.internalUpdateBusQueueRewardParams(
                        reservationRate,
                        premiumRate,
                        minEmptyQueueAge,
                    ),
                ).to.revertedWith('BQ:INVALID_PARAMS');
            });
        });
    });

    async function estimateRewards(
        busQueues: MockBusQueues,
        queueReward: number,
        queuePendingBlocks: number,
    ) {
        const {reservationRate, premiumRate} = await busQueues.getParams();

        const contrib = BigNumber.from(queueReward)
            .mul(reservationRate)
            .div(hundredPercent);

        const reward = BigNumber.from(queueReward).sub(contrib);

        const premium = BigNumber.from(queueReward)
            .mul(queuePendingBlocks)
            .mul(premiumRate)
            .div(hundredPercent);

        const netReserveChange = contrib.sub(premium);

        return {contrib, reward, premium, netReserveChange};
    }

    describe('_estimateRewarding and _computeReward', () => {
        let queue: BusQueues.BusQueueStruct;
        let currentBlockNumber: number;
        let queuePendingBlocks: number;
        const _reservationRate = 5_00; // 5%
        const _premiumRate = 1_00; // 1%
        const _minEmptyQueueAge = 65535; // max.uint16

        beforeEach(async () => {
            busQueues = await getNewBusQueuesInstance();

            await updateBusQueueRewardParams(busQueues, {
                reservationRate: _reservationRate,
                premiumRate: _premiumRate,
                minEmptyQueueAge: _minEmptyQueueAge,
            });

            currentBlockNumber = await getBlockNumber();
        });

        describe('_estimateRewarding', () => {
            beforeEach(async () => {
                queuePendingBlocks = 50;
                queue = {
                    nUtxos: 0,
                    reward: '100',
                    firstUtxoBlock: currentBlockNumber - queuePendingBlocks,
                    lastUtxoBlock: 0,
                    prevLink: 0,
                    nextLink: 0,
                };
            });

            describe('Success', () => {
                it('estimates the queue mining reward', async () => {
                    const {reward, premium, netReserveChange} =
                        await busQueues.internalEstimateRewarding(queue);

                    const {
                        reward: expectedReward,
                        premium: expectedPremium,
                        netReserveChange: expectedNetReserveChange,
                    } = await estimateRewards(
                        busQueues,
                        +queue.reward.toString(),
                        queuePendingBlocks,
                    );

                    expect(reward).to.be.eq(expectedReward);
                    expect(premium).to.be.eq(expectedPremium);
                    expect(netReserveChange).to.be.eq(expectedNetReserveChange);
                });
            });

            describe('Failure', () => {});
        });

        describe('_computeReward', () => {
            describe('Success', () => {
                describe('when miner supplies to the reward reserves', () => {
                    beforeEach(async () => {
                        queuePendingBlocks = 1;

                        queue = {
                            nUtxos: 0,
                            reward: '100',
                            firstUtxoBlock:
                                currentBlockNumber - queuePendingBlocks,
                            lastUtxoBlock: 0,
                            prevLink: 0,
                            nextLink: 0,
                        };
                    });

                    it('should increase the reward reserves', async () => {
                        const {netReserveChange} = await estimateRewards(
                            busQueues,
                            +queue.reward.toString(),
                            queuePendingBlocks + 1, // Todo: fix the block num inconsistency
                        );

                        await expect(busQueues.internalComputeReward(queue))
                            .to.emit(busQueues, 'BusQueueRewardReserved')
                            .withArgs(netReserveChange);

                        expect(await busQueues.getRewardReserve()).to.be.eq(
                            netReserveChange,
                        );
                    });
                });

                describe('when miner demands from the reward reserves', () => {
                    let estimatedReward: {
                        contrib: BigNumber;
                        reward: BigNumber;
                        premium: BigNumber;
                        netReserveChange: BigNumber;
                    };

                    beforeEach(async () => {
                        queuePendingBlocks = 100;

                        queue = {
                            nUtxos: 0,
                            reward: '9', // 9 gonna be demanded
                            firstUtxoBlock:
                                currentBlockNumber - queuePendingBlocks,
                            lastUtxoBlock: 0,
                            prevLink: 0,
                            nextLink: 0,
                        };

                        estimatedReward = await estimateRewards(
                            busQueues,
                            +queue.reward.toString(),
                            queuePendingBlocks,
                        );

                        expect(estimatedReward.netReserveChange).to.be.eq(-9);
                    });

                    describe('when the demand is less than the reward reserves', () => {
                        const rewardReserve = BigNumber.from(10);

                        beforeEach(async () => {
                            await busQueues.setRewardReserve(rewardReserve);
                        });

                        it('should decrease the reward reserves', async () => {
                            const {netReserveChange} = estimatedReward;

                            await expect(busQueues.internalComputeReward(queue))
                                .to.emit(busQueues, 'BusQueueRewardReserveUsed')
                                .withArgs(netReserveChange.abs());

                            expect(await busQueues.getRewardReserve()).to.be.eq(
                                rewardReserve.add(netReserveChange), // rewardReserve + (-netReserveChange)
                            );
                        });
                    });

                    describe('when the demand is more than the reward reserves', () => {
                        const rewardReserve = BigNumber.from(5);

                        beforeEach(async () => {
                            await busQueues.setRewardReserve(rewardReserve);
                        });

                        it('should decrease both the miner premium reward and the reward reserves', async () => {
                            await expect(busQueues.internalComputeReward(queue))
                                .to.emit(busQueues, 'BusQueueRewardReserveUsed')
                                .withArgs(rewardReserve);

                            expect(await busQueues.getRewardReserve()).to.be.eq(
                                0,
                            );
                        });
                    });
                });
            });
        });
    });

    describe.only('_getQueueRemainingBlocks', () => {
        let queue: BusQueues.BusQueueStruct;
        let currentBlockNumber: number;
        const reservationRate = 5_00; // 5%
        const premiumRate = 1_00; // 1%
        const minEmptyQueueAge = 50; // min number of blocks

        beforeEach(async () => {
            currentBlockNumber = await getBlockNumber();

            await updateBusQueueRewardParams(busQueues, {
                reservationRate,
                premiumRate,
                minEmptyQueueAge,
            });
        });

        it('should return 0 when the queue is fully populated', async () => {
            queue = generateQueue({nUtxos: maxQueueSize});
            const blocks =
                await busQueues.internalGetQueueRemainingBlocks(queue);

            expect(blocks).to.be.eq(0);
        });

        it('should calculate the remaining block for empty queue', async () => {
            const pendingBlock = 0;
            const firstUtxoBlock = currentBlockNumber - pendingBlock;

            queue = generateQueue({nUtxos: 0, firstUtxoBlock});

            const expectedRemainingBlocks =
                (maxQueueSize * minEmptyQueueAge) / maxQueueSize;

            const maturityBlock = minEmptyQueueAge + firstUtxoBlock;

            const blocks =
                await busQueues.internalGetQueueRemainingBlocks(queue);

            console.log(blocks);
        });
    });
});
