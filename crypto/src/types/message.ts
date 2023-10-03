export type ICiphertext = Uint8Array;

export type Plaintext = bigint[];

export type DecryptedZAccountUTXOMessage = {
    secretRandom: bigint;
    networkId: bigint;
    zoneId: bigint;
    nonce: bigint;
    expiryTime: bigint;
    amountZkp: bigint;
    amountPrp: bigint;
    totalAmountPerTimePeriod: bigint;
};
