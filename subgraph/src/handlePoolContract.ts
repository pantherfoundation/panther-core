import {
    FeesAccounted as FeesAccountedEvent,
    KycRewardUpdated as KycRewardUpdatedEvent,
    MainCircuitIdUpdated as MainCircuitIdUpdatedEvent,
    MaxTimeDeltaUpdated as MaxTimeDeltaUpdatedEvent,
    PrpAccountConversionCircuitIdUpdated as PrpAccountConversionCircuitIdUpdatedEvent,
    PrpAccountingCircuitIdUpdated as PrpAccountingCircuitIdUpdatedEvent,
    RootUpdated as RootUpdatedEvent,
    SeenKytMessageHash as SeenKytMessageHashEvent,
    TransactionNote as TransactionNoteEvent,
    VaultAssetUnlockerUpdated as VaultAssetUnlockerUpdatedEvent,
    ZAccountRegistrationCircuitIdUpdated as ZAccountRegistrationCircuitIdUpdatedEvent,
} from '../generated/PantherPoolV1/PantherPoolV1';
import {
    FeesAccounted,
    KycRewardUpdated,
    MainCircuitIdUpdated,
    MaxTimeDeltaUpdated,
    PrpAccountConversionCircuitIdUpdated,
    PrpAccountingCircuitIdUpdated,
    RootUpdated,
    SeenKytMessageHash,
    TransactionNote,
    VaultAssetUnlockerUpdated,
    ZAccountRegistrationCircuitIdUpdated,
} from '../generated/schema';

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

export function handleKycRewardUpdated(event: KycRewardUpdatedEvent): void {
    let entity = new KycRewardUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newReward = event.params.newReward;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleMainCircuitIdUpdated(
    event: MainCircuitIdUpdatedEvent,
): void {
    let entity = new MainCircuitIdUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newId = event.params.newId;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleMaxTimeDeltaUpdated(
    event: MaxTimeDeltaUpdatedEvent,
): void {
    let entity = new MaxTimeDeltaUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newMaxTimeDelta = event.params.newMaxTimeDelta;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handlePrpAccountConversionCircuitIdUpdated(
    event: PrpAccountConversionCircuitIdUpdatedEvent,
): void {
    let entity = new PrpAccountConversionCircuitIdUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newId = event.params.newId;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handlePrpAccountingCircuitIdUpdated(
    event: PrpAccountingCircuitIdUpdatedEvent,
): void {
    let entity = new PrpAccountingCircuitIdUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newId = event.params.newId;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleRootUpdated(event: RootUpdatedEvent): void {
    let entity = new RootUpdated(
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

export function handleSeenKytMessageHash(event: SeenKytMessageHashEvent): void {
    let entity = new SeenKytMessageHash(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.kytMessageHash = event.params.kytMessageHash;

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

export function handleVaultAssetUnlockerUpdated(
    event: VaultAssetUnlockerUpdatedEvent,
): void {
    let entity = new VaultAssetUnlockerUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newAssetUnlocker = event.params.newAssetUnlocker;
    entity.status = event.params.status;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleZAccountRegistrationCircuitIdUpdated(
    event: ZAccountRegistrationCircuitIdUpdatedEvent,
): void {
    let entity = new ZAccountRegistrationCircuitIdUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.newId = event.params.newId;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
