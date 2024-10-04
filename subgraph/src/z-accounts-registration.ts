import {
    BlacklistForMasterEoaUpdated as BlacklistForMasterEoaUpdatedEvent,
    BlacklistForPubRootSpendingKeyUpdated as BlacklistForPubRootSpendingKeyUpdatedEvent,
    BlacklistForZAccountIdUpdated as BlacklistForZAccountIdUpdatedEvent,
    FeesAccounted as FeesAccountedEvent,
    TransactionNote as TransactionNoteEvent,
    ZAccountActivated as ZAccountActivatedEvent,
    ZAccountRegistered as ZAccountRegisteredEvent,
} from '../generated/ZAccountsRegistration/ZAccountsRegistration';
import {
    BlacklistForMasterEoaUpdated,
    BlacklistForPubRootSpendingKeyUpdated,
    BlacklistForZAccountIdUpdated,
    FeesAccounted,
    TransactionNote,
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

export function handleFeesAccounted(event: FeesAccountedEvent): void {
    let entity = new FeesAccounted(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.chargedFeesPerTx_scMiningReward =
        event.params.chargedFeesPerTx.scMiningReward;
    entity.chargedFeesPerTx_scKytFees = event.params.chargedFeesPerTx.scKytFees;
    entity.chargedFeesPerTx_scKycFee = event.params.chargedFeesPerTx.scKycFee;
    entity.chargedFeesPerTx_scPaymasterCompensationInNative =
        event.params.chargedFeesPerTx.scPaymasterCompensationInNative;
    entity.chargedFeesPerTx_protocolFee =
        event.params.chargedFeesPerTx.protocolFee;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleTransactionNote(event: TransactionNoteEvent): void {
    let entity = new TransactionNote(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.txType = event.params.txType;
    entity.content = event.params.content;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleZAccountActivated(event: ZAccountActivatedEvent): void {
    let entity = new ZAccountActivated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.ZAccountsRegistration_id = event.params.id;

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
