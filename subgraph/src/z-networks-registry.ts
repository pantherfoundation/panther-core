import {ZNetworkTreeUpdated as ZNetworkTreeUpdatedEvent} from '../generated/ZNetworksRegistry/ZNetworksRegistry';
import {ZNetworkTreeUpdated} from '../generated/schema';

export function handleZNetworkTreeUpdated(
    event: ZNetworkTreeUpdatedEvent,
): void {
    let entity = new ZNetworkTreeUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newRoot = event.params.newRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
