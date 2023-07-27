import {TransactionNote as TransactionNoteEvent} from '../generated/PoolContract/PoolContract';
import {TransactionNote} from '../generated/schema';

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
