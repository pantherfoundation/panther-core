// should have few more classes for keypair,
// differentiate between master keypair and derived
// rootkeypair, keypair and derived keypair

export type EcdhSharedKey = [bigint, bigint]; // [y, x]
export type ephemeralKeyPacked = Uint8Array;

export type PrivateKey = bigint;
export type PublicKeyX = bigint;
export type PublicKeyY = bigint;
export type PublicKey = [bigint, bigint]; // [y, x]
export type Point = [bigint, bigint]; // [y, x]

export type Keypair = {
    publicKey: PublicKey;
    privateKey: PrivateKey;
};

export type WalletKeypairs = Record<
    'rootSpendingKeypair' | 'rootReadingKeypair' | 'storageEncryptionKeypair',
    Keypair
>;
