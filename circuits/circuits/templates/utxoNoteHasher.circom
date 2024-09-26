//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

// 2 Level hash, first level is private parameters, second level is quasi-private,
// since in generare-deposits api, spendPk, zAsset and amount are publicly know parameters
//    Cheating on the Receiver's Root Spending Key (Bug)
//    ==================================================
//
//    ## Issue Description
//    When creating a UTXO, the spender must prove in zero-knowledge (ZK) that the UTXO's spending
//    public key was derived correctly from the root spending public key of the receiver (i.e. the
//    owner of the UTXO being created) known by the spender:
//    `UtxoSpendKey = utxoRandom * RootSpendPubkey`
//
//    Creating a UTXO, the spender must prove in ZK:
//    - the UTXO's spending key is properly derived from a root spending pubkey the spender knows:
//      `UtxoSpendKey = utxoRandom * RootSpendPubkey`,
//      (Here, `UtxoSpendKey` and `RootSpendPubkey` are elliptic curve points from the BabyJubjub
//      subgroup, and `utxoRandom` is a scalar value less than the subgroup order, chosen at random).
//    - the encrypted Data Escrow record includes the correct root spending public key.
//
//    The correctness of the UTXO receiver's root spending public key is crucial for several protocol
//    compliance-related features:
//    - Users can find ZAccount public data (e.g., the EoA, Reading, and Nullifying public keys) using
//      the root spending public key.
//    - The Data Escrow operator (either the Compliance provider or the Zone Manager) can identify the
//      UTXO receiver by the root spending public key contained in the decrypted Data Escrow record.
//    - The Data Escrow operator, using the spender's nullifier public key from the ZAccount Registry
//      for the known RootSpendPubkey, can compute the nullifier for the UTXO and find the transaction
//      that spends it, if such a transaction exists.
//    - Users can perform selective disclosures based on the trusted Data Escrow data, including the
//     `RootSpendPubkey`.
//
//    The problem is as follows.
//
//    ZK-circuits verify that the root spending public key provided by the spender as a private input
//    matches the value recorded in the ZAccount Registry (ZAccountsTree). This verification is only
//    performed for UTXOs that are being spent, not for those that are being created by a transaction.
//
//    Therefore, the spender can cheat about the receiver's root spending public key when creating a
//    UTXO - instead of using the genuine public key registered in the ZAccount Registry, the spender
//    can provide a modified key:
//    `ModifiedRootSpendPubkey = hidingRandom * RootSpendPubkey`
//    (Here, hidingRandom is a scalar value known by the receiver).
//
//    Subsequently, to spend the UTXO, the receiver provides a modified `utxoRandom`:
//    `modifiedUtxoRandom = utxoRandom * hidingRandom`.
//    Before that, but after the UTXO was created, the receiver should register a blank ZAccount with
//    the `ModifiedRootSpendPubkey`.
//
//    With these modifications, ZK-circuits will accept the proofs for both UTXO creation and spending.
//    However, this results in broken compliance features due to the false (hidden) root spending public
//    key of the UTXO owner.
//
//    ## Solution
//    The UTXO commitment needs to be updated as follows: extend with the hash ( `utxoRandom` ).
//    This modification ensures that providing different `RootSpendPubkey` and `utxoRandom` values
//    in the creation and spending of a UTXO is impossible.
//    The inner hash is necessary to conceal the UTXO random if other UTXO
//    parameters need to be revealed (opened).
//
template UtxoNoteHasher(isHiddenHash){
    signal input {sub_order_bj_p}  spendPk[2];            // 254
    signal input {sub_order_bj_sf} random;                // 254
    signal input {uint64}          zAsset;                // 64
    signal input {uint64}          amount;                // 64
    signal input {uint6}           originNetworkId;       // 6
    signal input {uint6}           targetNetworkId;       // 6
    signal input {uint32}          createTime;            // 32
    signal input {uint16}          originZoneId;          // 16
    signal input {uint16}          targetZoneId;          // 16
    signal input {uint24}          zAccountId;            // 24
    signal input {sub_order_bj_p}  dataEscrowPubKey[2];   // 254

    signal output out;

    // 2 x 6-bit-networkId | 32-bit-createTime | 16-bit-origin-zone-id | 16-bit-target-zone-id
    assert(originNetworkId < 2**6);
    assert(targetNetworkId < 2**6);
    assert(createTime < 2**32);
    assert(originZoneId < 2**16);
    assert(targetZoneId < 2**16);
    assert(zAccountId < 2**24);

    component random_hash = Poseidon(1);
    random_hash.inputs[0] <== random;

    component hidden_hash = Poseidon(12);
    hidden_hash.inputs[0] <== spendPk[0];
    hidden_hash.inputs[1] <== spendPk[1];
    hidden_hash.inputs[2] <== random_hash.out;
    hidden_hash.inputs[3] <== zAsset;
    hidden_hash.inputs[4] <== zAccountId;
    hidden_hash.inputs[5] <== originNetworkId;
    hidden_hash.inputs[6] <== targetNetworkId;
    hidden_hash.inputs[7] <== createTime;
    hidden_hash.inputs[8] <== originZoneId;
    hidden_hash.inputs[9] <== targetZoneId;
    hidden_hash.inputs[10] <== dataEscrowPubKey[0];
    hidden_hash.inputs[11] <== dataEscrowPubKey[1];

    // quasi-public hash - used for generate-deposits
    component hasher = Poseidon(2);

    hasher.inputs[0] <== amount;
    hasher.inputs[1] <== hidden_hash.out;

    if ( isHiddenHash ) {
        out <== hidden_hash.out;
    }
    else {
        out <== hasher.out;
    }
}
