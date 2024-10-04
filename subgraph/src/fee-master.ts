import {
    DebtsUpdated as DebtsUpdatedEvent,
    DonationsUpdated as DonationsUpdatedEvent,
    FeeParamsUpdated as FeeParamsUpdatedEvent,
    NativeTokenReserveTargetUpdated as NativeTokenReserveTargetUpdatedEvent,
    NativeTokenReserveUpdated as NativeTokenReserveUpdatedEvent,
    PayOff as PayOffEvent,
    PoolUpdated as PoolUpdatedEvent,
    ProtocolZkpFeeDistributionParamsUpdated as ProtocolZkpFeeDistributionParamsUpdatedEvent,
    TwapPeriodUpdated as TwapPeriodUpdatedEvent,
    ZkpTokenDonationsUpdated as ZkpTokenDonationsUpdatedEvent,
    ZkpsDistributed as ZkpsDistributedEvent,
} from '../generated/feeMaster/feeMaster';
import {
    DebtsUpdated,
    DonationsUpdated,
    FeeParamsUpdated,
    NativeTokenReserveTargetUpdated,
    NativeTokenReserveUpdated,
    PayOff,
    PoolUpdated,
    ProtocolZkpFeeDistributionParamsUpdated,
    TwapPeriodUpdated,
    ZkpTokenDonationsUpdated,
    ZkpsDistributed,
} from '../generated/schema';

export function handleDebtsUpdated(event: DebtsUpdatedEvent): void {
    let entity = new DebtsUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.provider = event.params.provider;
    entity.token = event.params.token;
    entity.updatedDebt = event.params.updatedDebt;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleDonationsUpdated(event: DonationsUpdatedEvent): void {
    let entity = new DonationsUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.txType = event.params.txType;
    entity.donation = event.params.donation;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleFeeParamsUpdated(event: FeeParamsUpdatedEvent): void {
    let entity = new FeeParamsUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.feeParams_scPerUtxoReward = event.params.feeParams.scPerUtxoReward;
    entity.feeParams_scPerKytFee = event.params.feeParams.scPerKytFee;
    entity.feeParams_scKycFee = event.params.feeParams.scKycFee;
    entity.feeParams_protocolFeePercentage =
        event.params.feeParams.protocolFeePercentage;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleNativeTokenReserveTargetUpdated(
    event: NativeTokenReserveTargetUpdatedEvent,
): void {
    let entity = new NativeTokenReserveTargetUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.nativeTokenReserveTarget = event.params.nativeTokenReserveTarget;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleNativeTokenReserveUpdated(
    event: NativeTokenReserveUpdatedEvent,
): void {
    let entity = new NativeTokenReserveUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.nativeTokenReserve = event.params.nativeTokenReserve;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handlePayOff(event: PayOffEvent): void {
    let entity = new PayOff(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.receiver = event.params.receiver;
    entity.token = event.params.token;
    entity.amount = event.params.amount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handlePoolUpdated(event: PoolUpdatedEvent): void {
    let entity = new PoolUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.pool = event.params.pool;
    entity.enabled = event.params.enabled;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleProtocolZkpFeeDistributionParamsUpdated(
    event: ProtocolZkpFeeDistributionParamsUpdatedEvent,
): void {
    let entity = new ProtocolZkpFeeDistributionParamsUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.treasuryLockPercentage = event.params.treasuryLockPercentage;
    entity.minRewardableZkpAmount = event.params.minRewardableZkpAmount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleTwapPeriodUpdated(event: TwapPeriodUpdatedEvent): void {
    let entity = new TwapPeriodUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.twapPeriod = event.params.twapPeriod;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleZkpTokenDonationsUpdated(
    event: ZkpTokenDonationsUpdatedEvent,
): void {
    let entity = new ZkpTokenDonationsUpdated(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.zkpTokenDonation = event.params.zkpTokenDonation;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleZkpsDistributed(event: ZkpsDistributedEvent): void {
    let entity = new ZkpsDistributed(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.totalAmount = event.params.totalAmount;
    entity.minerPremiumRewards = event.params.minerPremiumRewards;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
