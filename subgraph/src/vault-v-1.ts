import {
    DepositedToEscrow as DepositedToEscrowEvent,
    FundedFromEscrow as FundedFromEscrowEvent,
    Locked as LockedEvent,
    ReturnedFromEscrow as ReturnedFromEscrowEvent,
    SaltUsed as SaltUsedEvent,
    Unlocked as UnlockedEvent,
} from '../generated/vaultV1/vaultV1';
import {
    DepositedToEscrow,
    FundedFromEscrow,
    Locked,
    ReturnedFromEscrow,
    SaltUsed,
    Unlocked,
} from '../generated/schema';

export function handleDepositedToEscrow(event: DepositedToEscrowEvent): void {
    let entity = new DepositedToEscrow(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.depositor = event.params.depositor;
    entity.value = event.params.value;
    entity.salt = event.params.salt;
    entity.escrow = event.params.escrow;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleFundedFromEscrow(event: FundedFromEscrowEvent): void {
    let entity = new FundedFromEscrow(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.depositor = event.params.depositor;
    entity.value = event.params.value;
    entity.salt = event.params.salt;
    entity.escrow = event.params.escrow;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleLocked(event: LockedEvent): void {
    let entity = new Locked(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.data_tokenType = event.params.data.tokenType;
    entity.data_token = event.params.data.token;
    entity.data_tokenId = event.params.data.tokenId;
    entity.data_extAccount = event.params.data.extAccount;
    entity.data_extAmount = event.params.data.extAmount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleReturnedFromEscrow(event: ReturnedFromEscrowEvent): void {
    let entity = new ReturnedFromEscrow(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.depositor = event.params.depositor;
    entity.value = event.params.value;
    entity.salt = event.params.salt;
    entity.escrow = event.params.escrow;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleSaltUsed(event: SaltUsedEvent): void {
    let entity = new SaltUsed(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.salt = event.params.salt;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}

export function handleUnlocked(event: UnlockedEvent): void {
    let entity = new Unlocked(
        event.transaction.hash.concatI32(event.logIndex.toI32()),
    );
    entity.data_tokenType = event.params.data.tokenType;
    entity.data_token = event.params.data.token;
    entity.data_tokenId = event.params.data.tokenId;
    entity.data_extAccount = event.params.data.extAccount;
    entity.data_extAmount = event.params.data.extAmount;

    entity.blockNumber = event.block.number;
    entity.blockTimestamp = event.block.timestamp;
    entity.transactionHash = event.transaction.hash;

    entity.save();
}
