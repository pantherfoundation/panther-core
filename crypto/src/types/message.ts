export type ICiphertext = Uint8Array;

export type Plaintext = bigint[];

export type UTXOMessage = {
    secretRandom?: bigint;
    commitment?: bigint;
    zAccountId?: bigint;
    zAssetId?: bigint;
    originNetworkId?: bigint;
    targetNetworkId?: bigint;
    originZoneId?: bigint;
    targetZoneId?: bigint;
    networkId?: bigint;
    zoneId?: bigint;
    nonce?: bigint;
    expiryTime?: bigint;
    amountZkp?: bigint;
    amountPrp?: bigint;
    scaledAmount?: bigint;
    totalAmountPerTimePeriod?: bigint;
};

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
