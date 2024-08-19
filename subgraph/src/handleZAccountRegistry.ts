import {
    BlacklistForMasterEoaUpdated as BlacklistForMasterEoaUpdatedEvent,
    BlacklistForPubRootSpendingKeyUpdated as BlacklistForPubRootSpendingKeyUpdatedEvent,
    BlacklistForZAccountIdUpdated as BlacklistForZAccountIdUpdatedEvent,
    ZAccountActivated as ZAccountActivatedEvent,
    ZAccountRegistered as ZAccountRegisteredEvent,
} from '../generated/ZAccountRegistry/ZAccountRegistry';
import {
    BlacklistForMasterEoaUpdated,
    BlacklistForPubRootSpendingKeyUpdated,
    BlacklistForZAccountIdUpdated,
    ZAccountActivated,
    ZAccountRegistered,
} from '../generated/schema';

export function handleBlacklistForMasterEoaUpdated(
    event: BlacklistForMasterEoaUpdatedEvent,
): void {
    let entity = new BlacklistForMasterEoaUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.masterEoa = event.params.masterEoa;
    entity.isBlackListed = event.params.isBlackListed;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBlacklistForPubRootSpendingKeyUpdated(
    event: BlacklistForPubRootSpendingKeyUpdatedEvent,
): void {
    let entity = new BlacklistForPubRootSpendingKeyUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.packedPubRootSpendingKey = event.params.packedPubRootSpendingKey;
    entity.isBlackListed = event.params.isBlackListed;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleBlacklistForZAccountIdUpdated(
    event: BlacklistForZAccountIdUpdatedEvent,
): void {
    let entity = new BlacklistForZAccountIdUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.zAccountId = event.params.zAccountId;
    entity.isBlackListed = event.params.isBlackListed;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleZAccountActivated(event: ZAccountActivatedEvent): void {
    let entity = new ZAccountActivated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.ZAccountRegistry_id = event.params.id;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleZAccountRegistered(event: ZAccountRegisteredEvent): void {
    let entity = new ZAccountRegistered(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.masterEoa = event.params.masterEoa;
    entity.zAccount__unused = event.params.zAccount._unused;
    entity.zAccount_creationBlock = event.params.zAccount.creationBlock;
    entity.zAccount_id = event.params.zAccount.id;
    entity.zAccount_version = event.params.zAccount.version;
    entity.zAccount_status = event.params.zAccount.status;
    entity.zAccount_pubRootSpendingKey =
        event.params.zAccount.pubRootSpendingKey;
    entity.zAccount_pubReadingKey = event.params.zAccount.pubReadingKey;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
