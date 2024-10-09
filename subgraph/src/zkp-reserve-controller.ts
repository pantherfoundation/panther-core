import {
    RewardParamsUpdated as RewardParamsUpdatedEvent,
    ZkpReservesReleased as ZkpReservesReleasedEvent,
} from '../generated/zkpReserveController/zkpReserveController';
import {RewardParamsUpdated, ZkpReservesReleased} from '../generated/schema';

export function handleRewardParamsUpdated(
    event: RewardParamsUpdatedEvent,
): void {
    let entity = new RewardParamsUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.releasablePerBlock = event.params.releasablePerBlock;
    entity.minRewardableAmount = event.params.minRewardableAmount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleZkpReservesReleased(
    event: ZkpReservesReleasedEvent,
): void {
    let entity = new ZkpReservesReleased(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.saltHash = event.params.saltHash;
    entity.amount = event.params.amount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
