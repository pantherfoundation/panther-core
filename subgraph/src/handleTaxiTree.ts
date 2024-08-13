import {
    TaxiRootUpdated as TaxiRootUpdatedEvent,
    TaxiSubtreeRootUpdated as TaxiSubtreeRootUpdatedEvent,
    TaxiUtxoAdded as TaxiUtxoAddedEvent,
} from '../generated/TaxiTree/TaxiTree';
import {
    TaxiRootUpdated,
    TaxiSubtreeRootUpdated,
    TaxiUtxoAdded,
} from '../generated/schema';

export function handleTaxiRootUpdated(event: TaxiRootUpdatedEvent): void {
    let entity = new TaxiRootUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.updatedRoot = event.params.updatedRoot;
    entity.numLeaves = event.params.numLeaves;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleTaxiSubtreeRootUpdated(
    event: TaxiSubtreeRootUpdatedEvent,
): void {
    let entity = new TaxiSubtreeRootUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.subtreeRoot = event.params.subtreeRoot;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleTaxiUtxoAdded(event: TaxiUtxoAddedEvent): void {
    let entity = new TaxiUtxoAdded(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.utxo = event.params.utxo;
    entity.totalUtxoInsertions = event.params.totalUtxoInsertions;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
