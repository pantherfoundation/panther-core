export type ICiphertext = Uint8Array;

export type Plaintext = bigint[];

export type ZAccountUTXOMessage = {
    secretRandom: bigint;
    networkId: bigint;
    zoneId: bigint;
    nonce: bigint;
    expiryTime: bigint;
    amountZkp: bigint;
    amountPrp: bigint;
    totalAmountPerTimePeriod: bigint;
};

export type ZAssetPrivUTXOMessage = {
    secretRandom: bigint;
    zAccountId: bigint;
    zAssetId: bigint;
    originNetworkId: bigint;
    targetNetworkId: bigint;
    originZoneId: bigint;
    targetZoneId: bigint;
};

export type ZAssetUTXOMessage = ZAssetPrivUTXOMessage & {
    scaledAmount: bigint;
};

export type SpentUTXOMessage = {
    spentUtxoCommitment1: bigint;
    spentUtxoCommitment2: bigint;
};

export type PrivateMessage =
    | ZAccountUTXOMessage
    | ZAssetUTXOMessage
    | ZAssetPrivUTXOMessage
    | SpentUTXOMessage;

type OptionalKeys<T> = {[P in keyof T]?: T[P]};
export type Message = OptionalKeys<
    ZAccountUTXOMessage &
        ZAssetUTXOMessage &
        ZAssetPrivUTXOMessage &
        SpentUTXOMessage
>;

export enum MessageType {
    ZAccount = 'ZAccount',
    ZAssetPriv = 'ZAssetPriv',
    ZAsset = 'ZAsset',
    SpentUTXO = 'SpentUTXO',
}
