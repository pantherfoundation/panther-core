import {
    BusBatchOnboarded as BusBatchOnboardedEvent,
    BusBranchFilled as BusBranchFilledEvent,
    BusQueueOpened as BusQueueOpenedEvent,
    BusQueueProcessed as BusQueueProcessedEvent,
    BusQueueRewardAdded as BusQueueRewardAddedEvent,
    BusQueueRewardParamsUpdated as BusQueueRewardParamsUpdatedEvent,
    BusQueueRewardReserveAllocated as BusQueueRewardReserveAllocatedEvent,
    BusQueueRewardReserveUpdated as BusQueueRewardReserveUpdatedEvent,
    ForestRootUpdated as ForestRootUpdatedEvent,
    MinerRewardAccounted as MinerRewardAccountedEvent,
    MinerRewardClaimed as MinerRewardClaimedEvent,
    TaxiRootUpdated as TaxiRootUpdatedEvent,
    TaxiSubtreeRootUpdated as TaxiSubtreeRootUpdatedEvent,
    TaxiUtxoAdded as TaxiUtxoAddedEvent,
    UtxoBusQueued as UtxoBusQueuedEvent,
} from '../generated/PantherForest/PantherForest';
import {
    BusBatchOnboarded,
    BusBranchFilled,
    BusQueueOpened,
    BusQueueProcessed,
    BusQueueRewardAdded,
    BusQueueRewardParamsUpdated,
    BusQueueRewardReserveAllocated,
    BusQueueRewardReserveUpdated,
    ForestRootUpdated,
    MinerRewardAccounted,
    MinerRewardClaimed,
    TaxiRootUpdated,
    TaxiSubtreeRootUpdated,
    TaxiUtxoAdded,
    UtxoBusQueued,
} from '../generated/schema';

export function handleBusBatchOnboarded(event: BusBatchOnboardedEvent): void {
    let entity = new BusBatchOnboarded(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.queueId = event.params.queueId;
    entity.batchRoot = event.params.batchRoot;
    entity.numUtxosInBatch = event.params.numUtxosInBatch;
    entity.leftLeafIndexInBusTree = event.params.leftLeafIndexInBusTree;
    entity.busTreeNewRoot = event.params.busTreeNewRoot;
    entity.busBranchNewRoot = event.params.busBranchNewRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    // update the corresponding BusQueueOpened entity
    const queue = BusQueueOpened.load(event.params.queueId.toString());
    if (queue != null) {
        queue.isOnboarded = true;
        queue.save();
    }

    entity.save();
}

export function handleBusBranchFilled(event: BusBranchFilledEvent): void {
    let entity = new BusBranchFilled(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.branchIndex = event.params.branchIndex;
    entity.busBranchFinalRoot = event.params.busBranchFinalRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusQueueOpened(event: BusQueueOpenedEvent): void {
    const entity = new BusQueueOpened(event.params.queueId.toString());
    entity.queueId = event.params.queueId;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.isOnboarded = false;

    entity.save();
}

export function handleBusQueueProcessed(event: BusQueueProcessedEvent): void {
    let entity = new BusQueueProcessed(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.queueId = event.params.queueId;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusQueueRewardAdded(
    event: BusQueueRewardAddedEvent,
): void {
    let entity = new BusQueueRewardAdded(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.queueId = event.params.queueId;
    entity.accumReward = event.params.accumReward;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusQueueRewardParamsUpdated(
    event: BusQueueRewardParamsUpdatedEvent,
): void {
    let entity = new BusQueueRewardParamsUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.reservationRate = event.params.reservationRate;
    entity.premiumRate = event.params.premiumRate;
    entity.minEmptyQueueAge = event.params.minEmptyQueueAge;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusQueueRewardReserveAllocated(
    event: BusQueueRewardReserveAllocatedEvent,
): void {
    let entity = new BusQueueRewardReserveAllocated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.updatedNetRewardReserve = event.params.updatedNetRewardReserve;
    entity.allocated = event.params.allocated;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBusQueueRewardReserveUpdated(
    event: BusQueueRewardReserveUpdatedEvent,
): void {
    let entity = new BusQueueRewardReserveUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.updatedNetRewardReserve = event.params.updatedNetRewardReserve;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleForestRootUpdated(event: ForestRootUpdatedEvent): void {
    let entity = new ForestRootUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.leafIndex = event.params.leafIndex;
    entity.updatedLeaf = event.params.updatedLeaf;
    entity.updatedRoot = event.params.updatedRoot;
    entity.cacheIndex = event.params.cacheIndex;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleMinerRewardAccounted(
    event: MinerRewardAccountedEvent,
): void {
    let entity = new MinerRewardAccounted(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.queueId = event.params.queueId;
    entity.miner = event.params.miner;
    entity.reward = event.params.reward;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleMinerRewardClaimed(event: MinerRewardClaimedEvent): void {
    let entity = new MinerRewardClaimed(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.timestamp = event.params.timestamp;
    entity.miner = event.params.miner;
    entity.reward = event.params.reward;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleTaxiRootUpdated(event: TaxiRootUpdatedEvent): void {
    let entity = new TaxiRootUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.updatedRoot = event.params.updatedRoot;
    entity.numLeaves = event.params.numLeaves;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleTaxiSubtreeRootUpdated(
    event: TaxiSubtreeRootUpdatedEvent,
): void {
    let entity = new TaxiSubtreeRootUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.subtreeRoot = event.params.subtreeRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleTaxiUtxoAdded(event: TaxiUtxoAddedEvent): void {
    let entity = new TaxiUtxoAdded(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.utxo = event.params.utxo;
    entity.totalUtxoInsertions = event.params.totalUtxoInsertions;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleUtxoBusQueued(event: UtxoBusQueuedEvent): void {
    let entity = new UtxoBusQueued(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.utxo = event.params.utxo;
    entity.queueId = event.params.queueId;
    entity.utxoIndexInBatch = event.params.utxoIndexInBatch;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
