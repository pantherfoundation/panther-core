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

export type CommitmentMessage = {
    commitment: bigint;
};

export type PrivateMessage =
    | ZAccountUTXOMessage
    | ZAssetUTXOMessage
    | ZAssetPrivUTXOMessage
    | CommitmentMessage;

type OptionalKeys<T> = {[P in keyof T]?: T[P]};
export type Message = OptionalKeys<
    ZAccountUTXOMessage &
        ZAssetUTXOMessage &
        ZAssetPrivUTXOMessage &
        CommitmentMessage
>;

export enum MessageType {
    ZAccount = 'ZAccount',
    ZAssetPriv = 'ZAssetPriv',
    ZAsset = 'ZAsset',
    Commitment = 'Commitment',
}
