// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
// eslint-disable-next-line import/named
import {BigNumber, BigNumberish, ContractFactory} from 'ethers';
import {ethers} from 'hardhat';

import {getPoseidonT3Contract} from '../../../lib/poseidonBuilder';
import {getBlockNumber} from '../../../lib/provider';
import {MockBusQueues} from '../../../types/contracts';
import {BusQueues} from '../../../types/contracts/MockBusQueues';
import {randomInputGenerator} from '../helpers/randomSnarkFriendlyInputGenerator';

const BigNumber = ethers.BigNumber;

describe('BusQueue contract', function () {
    let busQueueFactory: ContractFactory;
    let busQueues: MockBusQueues;

    const hundredPercent = 100_00;
    const maxQueueSize = 64;
    const zeroByte = ethers.constants.HashZero;

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

    function generateQueue(
        params: {
            [key: string]: BigNumberish;
        } = {},
    ): BusQueues.BusQueueStruct {
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
                            await busQueues.mockSetRewardReserve(rewardReserve);
                        });

                        it('should decrease the reward reserves', async () => {
                            const {netReserveChange} = estimatedReward;

                            const expectedNetRewardReserves =
                                rewardReserve.add(netReserveChange);

                            await expect(busQueues.internalComputeReward(queue))
                                .to.emit(busQueues, 'BusQueueRewardReserveUsed')
                                .withArgs(-netReserveChange); // 9

                            expect(await busQueues.getRewardReserve()).to.be.eq(
                                expectedNetRewardReserves,
                            );
                        });
                    });

                    describe('when the demand is more than the reward reserves', () => {
                        const rewardReserve = BigNumber.from(5);

                        beforeEach(async () => {
                            await busQueues.mockSetRewardReserve(rewardReserve);
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

    function calculateMinQueueAge(
        emptySeats: number,
        minEmptyQueueAge: number,
    ): number {
        return BigNumber.from(emptySeats)
            .mul(minEmptyQueueAge)
            .div(maxQueueSize)
            .toNumber();
    }

    describe('_getQueueRemainingBlocks', () => {
        let queue: BusQueues.BusQueueStruct;
        let currentBlockNumber: number;
        const reservationRate = 5_00; // 5%
        const premiumRate = 1_00; // 1%
        const minEmptyQueueAge = 256; // min number of blocks

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

        it('should calculate the remaining block for queue with 1 empty utxo', async () => {
            const numberOfEmptyUtxos = 1;
            const numberOfUtxos = 63;
            const pendingBlock = 1;
            const firstUtxoBlock = currentBlockNumber - pendingBlock;

            queue = generateQueue({nUtxos: numberOfUtxos, firstUtxoBlock});

            const minAge = calculateMinQueueAge(
                numberOfEmptyUtxos,
                minEmptyQueueAge,
            );
            expect(minAge).to.be.eq(4);

            const maturityBlock = minAge + firstUtxoBlock;

            const blocks =
                await busQueues.internalGetQueueRemainingBlocks(queue);

            currentBlockNumber = await getBlockNumber();
            expect(blocks).to.be.eq(maturityBlock - currentBlockNumber);
        });
    });

    async function createNewBusQueue(queue: BusQueues.BusQueueStruct) {
        await expect(busQueues.internalCreateNewBusQueue())
            .to.emit(busQueues, 'LogNewBusQueue')
            .withArgs(Object.values(queue));
    }

    describe('_createNewBusQueue', () => {
        it('should return the created queues', async () => {
            const queue = generateQueue({});

            await createNewBusQueue(queue);
            expect(await busQueues.getNextQueueId()).to.be.eq(1);

            await createNewBusQueue(queue);
            expect(await busQueues.getNextQueueId()).to.be.eq(2);
        });
    });

    async function addQueue(queue: BusQueues.BusQueueStruct, id: number) {
        await busQueues.mockAddQueue(queue, id);
    }

    describe('_addBusQueueReward', () => {
        let queue: BusQueues.BusQueueStruct;
        let queueId = 1;
        const queueReward = 1;
        const extraQueueReward = 10;

        beforeEach(async () => {
            queue = generateQueue({reward: queueReward, nUtxos: 1});
            await addQueue(queue, queueId);
        });

        describe('when the queue exists', () => {
            it('should increase the queue reward', async () => {
                const accumReward = queueReward + extraQueueReward;
                await expect(
                    busQueues.internalAddBusQueueReward(
                        queueId,
                        extraQueueReward,
                    ),
                )
                    .to.emit(busQueues, 'BusQueueRewardAdded')
                    .withArgs(queueId, accumReward);
            });
        });

        describe('when the queue is empty', () => {
            it('should revert', async () => {
                queueId = 99;

                await expect(
                    busQueues.internalAddBusQueueReward(
                        queueId,
                        extraQueueReward,
                    ),
                ).to.revertedWith('BQ:EMPTY_QUEUE');
            });
        });
    });

    function createUtxoBatch(length: number): string[] {
        return Array.from(Array(length).keys()).map(() =>
            randomInputGenerator(),
        );
    }

    describe('_addUtxosToBusQueue', () => {
        let utxos: string[];
        const rewards = 99;

        describe('Failure', () => {
            beforeEach(() => {
                utxos = createUtxoBatch(maxQueueSize + 1);
            });

            it('should revert when length is too high', async () => {
                await expect(
                    busQueues.internalAddUtxosToBusQueue(utxos, 1),
                ).to.revertedWith('BQ:TOO_MANY_UTXOS');
            });
        });

        describe('success', () => {
            const firstBatch = createUtxoBatch(12);
            const secondBatch = createUtxoBatch(61);
            const thirdBatch = createUtxoBatch(30);
            const forthBatch = createUtxoBatch(23);
            const fifthBatch = createUtxoBatch(4);

            const batches = [
                firstBatch,
                secondBatch,
                thirdBatch,
                forthBatch,
                fifthBatch,
            ];

            const queues = generateQueues(batches);

            it('should add utxos to queue', async () => {
                for (let index = 0; index < batches.length; index++) {
                    const batch = batches[index];
                    await expect(
                        busQueues.internalAddUtxosToBusQueue(batch, rewards),
                    ).to.emit(busQueues, 'LogQueueIdAndFirstIndex');
                }

                for (let index = 0; index < queues.length; index++) {
                    const queue = queues[index];
                    const expectedQueue = await busQueues.getBusQueue(index);

                    expect(expectedQueue.commitment).to.be.eq(queue.commitment);
                }

                expect(await busQueues.getNextQueueId()).to.be.eq(
                    queues.length,
                );
                expect(await busQueues.getNumPendingQueues()).to.be.eq(
                    queues.length,
                );
                expect(await busQueues.getOldestPendingQueueLink()).to.be.eq(1);
            });
        });
    });

    describe('getOldestPendingQueues', () => {
        const rewards = 99;
        const utxos = Array.from(Array(maxQueueSize - 1).keys()).map(() =>
            randomInputGenerator(),
        );

        beforeEach(async () => {
            await busQueues.internalAddUtxosToBusQueue(utxos, rewards);
        });

        describe('when the queue is non empty', async () => {
            it('should set queue as processed', async () => {
                const numberOfPendingQueues =
                    await busQueues.getNumPendingQueues();

                const queues = await busQueues.getOldestPendingQueues(
                    numberOfPendingQueues,
                );

                expect(queues.length).to.be.eq(1);
                expect(queues[0].nUtxos).to.be.eq(maxQueueSize - 1);
            });
        });
    });

    describe('_setBusQueueAsProcessed', () => {
        const rewards = 99;
        const utxos = createUtxoBatch(maxQueueSize - 1);

        beforeEach(async () => {
            await busQueues.internalAddUtxosToBusQueue(utxos, rewards);
        });

        it('should add utxos', async () => {
            await expect(busQueues.internalSetBusQueueAsProcessed(0))
                .to.emit(busQueues, 'BusQueueProcessed')
                .withArgs(0);
        });
    });

    function generateQueues(utxoBatches: string[][]) {
        const queues: {
            utxos: string[];
            queueId?: number;
            reward?: number;
            premium?: number;
            commitment?: string;
            nextLink?: number;
        }[] = [];
        let numberOfQueues = 0;

        for (let index = 0; index < utxoBatches.length; index++) {
            const utxos = utxoBatches[index];

            utxos.forEach(utxo => {
                let currentQueue = queues[numberOfQueues];

                if (!currentQueue) {
                    currentQueue = {utxos: []};
                }

                currentQueue.queueId = numberOfQueues;
                currentQueue.reward = 100;

                if (currentQueue.utxos.length < maxQueueSize) {
                } else {
                    currentQueue = {utxos: []};
                    numberOfQueues++;
                }

                currentQueue.utxos.push(utxo);
                queues[numberOfQueues] = currentQueue;
            });
        }

        queues.forEach(queue => {
            queue.commitment = getCommitment(queue.utxos);
        });

        return queues;
    }

    function getCommitment(utxos: string[]) {
        let commitment = zeroByte;
        let isFirstLeaf = true;

        utxos.forEach(utxo => {
            commitment = isFirstLeaf ? utxo : poseidon([commitment, utxo]);
            isFirstLeaf = false;
        });

        return commitment;
    }

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
});
