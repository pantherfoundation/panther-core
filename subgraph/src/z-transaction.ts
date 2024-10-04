import {
    FeesAccounted as FeesAccountedEvent,
    SeenKytMessageHash as SeenKytMessageHashEvent,
    TransactionNote as TransactionNoteEvent,
} from '../generated/ZTransaction/ZTransaction';
import {
    FeesAccounted,
    SeenKytMessageHash,
    TransactionNote,
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
