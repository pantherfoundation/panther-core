import {ZZonesTreeUpdated as ZZonesTreeUpdatedEvent} from '../generated/ZZonesRegistry/ZZonesRegistry';
import {ZZonesTreeUpdated} from '../generated/schema';

export function handleZZonesTreeUpdated(event: ZZonesTreeUpdatedEvent): void {
    let entity = new ZZonesTreeUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newRoot = event.params.newRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
