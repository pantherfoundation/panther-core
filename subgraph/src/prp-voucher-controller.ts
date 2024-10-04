import {
    FeesAccounted as FeesAccountedEvent,
    RewardAccounted as RewardAccountedEvent,
    RewardClaimed as RewardClaimedEvent,
    RewardVoucherGenerated as RewardVoucherGeneratedEvent,
    TransactionNote as TransactionNoteEvent,
    VoucherTermsUpdated as VoucherTermsUpdatedEvent,
} from '../generated/PrpVoucherController/PrpVoucherController';
import {
    FeesAccounted,
    RewardAccounted,
    RewardClaimed,
    RewardVoucherGenerated,
    TransactionNote,
    VoucherTermsUpdated,
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

export function handleRewardAccounted(event: RewardAccountedEvent): void {
    let entity = new RewardAccounted(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.secretHash = event.params.secretHash;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleRewardClaimed(event: RewardClaimedEvent): void {
    let entity = new RewardClaimed(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.secretHash = event.params.secretHash;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleRewardVoucherGenerated(
    event: RewardVoucherGeneratedEvent,
): void {
    let entity = new RewardVoucherGenerated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.secretHash = event.params.secretHash;
    entity.prpAmount = event.params.prpAmount;

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

export function handleVoucherTermsUpdated(
    event: VoucherTermsUpdatedEvent,
): void {
    let entity = new VoucherTermsUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.allowedContract = event.params.allowedContract;
    entity.voucherType = event.params.voucherType;
    entity.limit = event.params.limit;
    entity.amount = event.params.amount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
