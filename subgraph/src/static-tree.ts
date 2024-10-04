import {RootUpdated as RootUpdatedEvent} from '../generated/StaticTree/StaticTree';
import {RootUpdated} from '../generated/schema';

export function handleRootUpdated(event: RootUpdatedEvent): void {
    let entity = new RootUpdated(
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
