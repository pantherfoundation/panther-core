import {StaticRootUpdated as StaticRootUpdatedEvent} from '../generated/StaticTree/StaticTree';
import {StaticRootUpdated} from '../generated/schema';

export function handleRootUpdated(event: StaticRootUpdatedEvent): void {
    let entity = new StaticRootUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.leafIndex = event.params.leafIndex;
    entity.updatedLeaf = event.params.updatedLeaf;
    entity.updatedRoot = event.params.updatedRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
