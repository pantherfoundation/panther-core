import {
    WeightControllerUpdated as WeightControllerUpdatedEvent,
    ZAssetRootUpdated as ZAssetRootUpdatedEvent,
} from '../generated/ZAssetsRegistryV1/ZAssetsRegistryV1';
import {WeightControllerUpdated, ZAssetRootUpdated} from '../generated/schema';

export function handleWeightControllerUpdated(
    event: WeightControllerUpdatedEvent,
): void {
    let entity = new WeightControllerUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.weightController = event.params.weightController;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleZAssetRootUpdated(event: ZAssetRootUpdatedEvent): void {
    let entity = new ZAssetRootUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newRoot = event.params.newRoot;
    entity.zAssetInnerHash = event.params.zAssetInnerHash;
    entity.weight = event.params.weight;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
