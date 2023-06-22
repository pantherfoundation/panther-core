// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar

import {
    BusBatchOnboarded as BusBatchOnboardedEvent,
    BusBranchFilled as BusBranchFilledEvent,
    BusQueueOpened as BusQueueOpenedEvent,
    BusQueuePending as BusQueuePendingEvent,
    BusQueueProcessed as BusQueueProcessedEvent,
    MinerRewarded as MinerRewardedEvent,
    UtxoBusQueued as UtxoBusQueuedEvent,
} from '../generated/BusTree/BusTree';
import {
    BusBatchOnboarded,
    BusBranchFilled,
    BusQueueOpened,
    BusQueuePending,
    BusQueueProcessed,
    MinerRewarded,
    UtxoBusQueued,
} from '../generated/schema';
import {generateEntityId} from './utils/idGenerators';

export function handleBusBatchOnboarded(event: BusBatchOnboardedEvent): void {
    const entity = new BusBatchOnboarded(generateEntityId(event));
    entity.queueId = event.params.queueId;
    entity.batchRoot = event.params.batchRoot;
    entity.numUtxosInBatch = event.params.numUtxosInBatch;
    entity.leftLeafIndexInBusTree = event.params.leftLeafIndexInBusTree;
    entity.busTreeNewRoot = event.params.busTreeNewRoot;
    entity.busBranchNewRoot = event.params.busBranchNewRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusBranchFilled(event: BusBranchFilledEvent): void {
    const entity = new BusBranchFilled(generateEntityId(event));
    entity.branchIndex = event.params.branchIndex;
    entity.busBranchFinalRoot = event.params.busBranchFinalRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusQueueOpened(event: BusQueueOpenedEvent): void {
    const entity = new BusQueueOpened(generateEntityId(event));
    entity.queueId = event.params.queueId;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusQueuePending(event: BusQueuePendingEvent): void {
    const entity = new BusQueuePending(generateEntityId(event));
    entity.queueId = event.params.queueId;
    entity.accumReward = event.params.accumReward;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusQueueProcessed(event: BusQueueProcessedEvent): void {
    const entity = new BusQueueProcessed(generateEntityId(event));
    entity.queueId = event.params.queueId;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleMinerRewarded(event: MinerRewardedEvent): void {
    const entity = new MinerRewarded(generateEntityId(event));
    entity.miner = event.params.miner;
    entity.reward = event.params.reward;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleUtxoBusQueued(event: UtxoBusQueuedEvent): void {
    const entity = new UtxoBusQueued(generateEntityId(event));
    entity.utxo = event.params.utxo;
    entity.queueId = event.params.queueId;
    entity.utxoIndexInBatch = event.params.utxoIndexInBatch;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
