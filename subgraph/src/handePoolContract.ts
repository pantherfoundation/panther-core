import {
    RootUpdated as RootUpdatedEvent,
    TransactionNote as TransactionNoteEvent,
} from '../generated/PoolContract/PoolContract';
import {TransactionNote, RootUpdated} from '../generated/schema';

export function handleTransactionNote(event: TransactionNoteEvent): void {
    const entity = new TransactionNote(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.txType = event.params.txType;
    entity.content = event.params.content;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;
    entity.from = event.transaction.from.toHex();

    entity.save();
}

export function handleRootUpdated(event: RootUpdatedEvent): void {
    const entity = new RootUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.leafIndex = event.params.leafIndex;
    entity.updatedLeaf = event.params.updatedLeaf;
    entity.updatedRoot = event.params.updatedRoot;
    entity.cacheIndex = event.params.cacheIndex;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;
    entity.from = event.transaction.from.toHex();

    entity.save();
}
