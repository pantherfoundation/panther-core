import {
    KeyExtended as KeyExtendedEvent,
    KeyRegistered as KeyRegisteredEvent,
    KeyRevoked as KeyRevokedEvent,
    KeyringUpdated as KeyringUpdatedEvent,
    TreeLockUpdated as TreeLockUpdatedEvent,
} from '../generated/ProvidersKeysRegistry/ProvidersKeysRegistry';
import {
    KeyExtended,
    KeyRegistered,
    KeyRevoked,
    KeyringUpdated,
    TreeLockUpdated,
} from '../generated/schema';

export function handleKeyExtended(event: KeyExtendedEvent): void {
    let entity = new KeyExtended(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.keyringId = event.params.keyringId;
    entity.keyIndex = event.params.keyIndex;
    entity.newExpiry = event.params.newExpiry;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleKeyRegistered(event: KeyRegisteredEvent): void {
    let entity = new KeyRegistered(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.keyringId = event.params.keyringId;
    entity.keyIndex = event.params.keyIndex;
    entity.packedPubKey = event.params.packedPubKey;
    entity.expiry = event.params.expiry;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleKeyRevoked(event: KeyRevokedEvent): void {
    let entity = new KeyRevoked(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.keyringId = event.params.keyringId;
    entity.keyIndex = event.params.keyIndex;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleKeyringUpdated(event: KeyringUpdatedEvent): void {
    let entity = new KeyringUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.keyringId = event.params.keyringId;
    entity.operator = event.params.operator;
    entity.status = event.params.status;
    entity.numAllocKeys = event.params.numAllocKeys;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleTreeLockUpdated(event: TreeLockUpdatedEvent): void {
    let entity = new TreeLockUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.tillTime = event.params.tillTime;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
