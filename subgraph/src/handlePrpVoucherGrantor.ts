import {
    RewardClaimed as RewardClaimedEvent,
    RewardVoucherGenerated as RewardVoucherGeneratedEvent,
    VoucherTermsUpdated as VoucherTermsUpdatedEvent,
} from '../generated/PRPVoucherGrantor/PRPVoucherGrantor';
import {
    RewardClaimed,
    RewardVoucherGenerated,
    VoucherTermsUpdated,
} from '../generated/schema';

export function handleRewardClaimed(event: RewardClaimedEvent): void {
    let entity = new RewardClaimed(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.secretHash = event.params.secretHash;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;
    entity.from = event.transaction.from.toHex();

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
    entity.from = event.transaction.from.toHex();

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
    entity.from = event.transaction.from.toHex();

    entity.save();
}
