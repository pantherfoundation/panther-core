import {
    FeesAccounted as FeesAccountedEvent,
    Initialized as InitializedEvent,
    Sync as SyncEvent,
    TransactionNote as TransactionNoteEvent,
    ZkpReservesIncreased as ZkpReservesIncreasedEvent,
} from '../generated/PrpConversion/PrpConversion';
import {
    FeesAccounted,
    Initialized,
    Sync,
    TransactionNote,
    ZkpReservesIncreased,
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

export function handleInitialized(event: InitializedEvent): void {
    let entity = new Initialized(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.prpVirtualAmount = event.params.prpVirtualAmount;
    entity.zkpAmount = event.params.zkpAmount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleSync(event: SyncEvent): void {
    let entity = new Sync(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.prpReserve = event.params.prpReserve;
    entity.zkpReserve = event.params.zkpReserve;

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

export function handleZkpReservesIncreased(
    event: ZkpReservesIncreasedEvent,
): void {
    let entity = new ZkpReservesIncreased(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.increasedAmount = event.params.increasedAmount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
