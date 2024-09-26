//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

///*
// This template computes the ZAssetsTree Leaf and verifies the Merkle proof of Leaf's inclusion
// in the ZAssetsTree.
//
// ZAsset
// ------
// A ZAsset represents a token within the MASP. The protocol considers a ZAsset to be a specific
// crypto token, identified by its token smart contract and, where applicable, a unique token ID
// (such as for ERC-721/ERC-1155 tokens) - referred to as the "external ID", combined with other
// parameters governing how the protocol handles the token.
//
// Batch of ZAssets
// ----------------
// A "Batch" is a set of one or more (up to 2^32) ZAssets which share common parameters.
//
// The words "Batch" and "Leafs" are often used interchangeably in comments since Batches "exist" as
// Leafs of the ZAssetsTree, as bellow explained.
//
// For fungible tokens, a Batch MUST contain a single ZAsset representing a single token (e.g., the
// Batch for the ZKP token).
// In the case of NFTs, a Batch may include a single ZAsset that represents a unique NFT (with its
// unique external ID), or multiple ZAssets representing many NFTs. In the latter case, NFTs MUST be
// on the same token contract but have distinct external IDs, falling in a range the Batch defines.
//
// A ZAsset may be contained by a single Batch only. In the case of a token circulating on multiple
// supported networks, multiple Batches may contain the same ZAsset representing this token.
//
// Batch ID
// ----------
// It is the ID of a Batch.
//
// It MUST be unique - smart contracts are assumed to force it.
// It is not the index of the Leaf in the ZAssetTree (and the index can not serve as the Batch ID -
// see "Token on multiple supported networks").
//
// Circuits match the ID of a Batch with the ID of a ZAsset to verify if the Batch "includes" the
// ZAsset and hence the Batch params should be employed for the ZAsset (see comments on matching in
// the file './zAssetChecker.circom').
//
// Format:
// It is a 64-bit number, where the upper 32 bits are used for matching the Batch and ZAsset IDs.
// The lower 32 bits are ignored by circuits. Smart contracts use them to make the Batch ID unique.
//
// !!! The ID of the Batch with the ZKP token MUST be 0.
//
// Examples:
// - the 10th registered Batch with an ERC-20 token will have the Batch ID of 9*2^32+0.
// - the 11th Batch with an NFT having the external ID 56 will have the Batch ID of 10*2^32+0,
//   'startTokenId' = 56, and 'offset' = 0 (params' description follows).
// - the 12th Batch with 33 NFTs, whose external IDs range from 167 to 199, will have the Batch ID
//   of 11*2^32+0, 'startTokenId' = 167, and 'offset' = 32.
//
// The circuit signal for the Batch ID is called 'zAsset' in the code bellow.
//
// ZAssetsTree
// -----------
// The ZAssetsTree is a binary Merkle tree, where each leaf is a commitment to the parameters of
// a Batch. Tokens (and ZAssets representing these tokens) are registered/enabled/disabled in the
// protocol via Batches.
//
// ZAssetsTree Leaf
// ----------------
// Each Leaf of the ZAssetsTree is a commitment to parameters of a Batch:
// ```
// zAssetLeaf = Poseidon([
//     Poseidon([
//         zAssetsBatchId,
//         tokenAddrAndType,
//         startTokenId,
//         network,
//         2^64 * offset + scale
//     ]),
//     weight
// ])
// ```
// Where,
// - 'zAssetsBatchId' - Batch ID.
// - 'tokenAddrAndType' - token type (ERC-20, ERC-721, ERC-1155) as a uint8, followed by the token
//   contract address as a uint160 (the signal for this is called 'token' in the code bellow).
// - 'startTokenId' (the signal is called 'tokenId' in the code bellow) and 'offset' define the
//   range of values for the external token ID: 'startTokenId ≤ tokenId ≤ startTokenId + offset'
// - 'network' - the network ID where the Batch's ZAssets can be spent.
// - 'scale' - the denominator for amount scaling (see "Amount Scaling").
// - 'weight' - the factor for amount weighting (see "Amount Weighting").
//
// Once registered, the Leaf's parameters are immutable, except for:
// - 'weight', which can be updated.
// - 'network', which to be set to 0x3f if Batch assets are disabled, and restored when re-enabled.
// Smart contracts are assumed to enforce it.
//
// Furthermore, smart contracts are assumed to enforce:
// - 'startTokenId + offset' must be within SNARK_FIELD_SIZE;
// - 'offset' must be 0 for a Batch with a single token (fungible or NFT);
// - for a Batch with an ERC-20 token both the 'offset' and the 'startTokenId' are 0.
//   The signal for the 'startTokenId' is called 'tokenId' in the circuit code bellow.
//
// Amount Scaling
// --------------
// The amounts stored in UTXOs, as operated on by ZK-circuits, are scaled relative to the amounts
// held by token smart contracts:
// ```
// scaledAmount = tokenContractAmount / scale
// ```
// Where, 'scale' is a parameter of the ZAssetsTree Leaf.
//
// Once defined for a ZAsset (its Batch), the 'scale' MUST never be changed.
// For NFTs, the 'scale' MUST be 1. So, the scaled amount of a UTXO representing any NFT is 1.
//
// Example:
// If the scale for ZKP is 1e+12 and ZKP has 18 decimals, then 0.5 ZKP is represented as:
// - 0.5e+18 ('tokenContractAmount') in the token contract.
// - 0.5e+6 ('scaledAmount') in a UTXO.
//
// Circuits limit scaled amounts to less than 2^64.
// The circuit signal for 'scale' is called by the same name.
//
// Amount Weighting
// ----------------
// Transaction limits and rewards are computed based on "weighted" amounts.
// A unit of the the weighted amount should worth approximately the same monetary (USD) value for
// any token, independent of token prices. To obtain it, a factor called 'weight' is used to derive
// the weighted amount from the scaled amount as follows.
// ```
// weightedAmount = scaledAmount * weight
// ```
// Where, 'weight' is a parameter of the ZAssetsTree Leaf and assumed to be updated time after time
// in order to (approximately) adjust for token market price changes.
//
// Circuits (and smart contracts) enforce that the 'weight' MUST be between 0 and 2^48-1.
//
// Circuits enforces that the weighted amounts MUST be less than 96 bits, which is enough since:
// - The scaled amount of a UTXO with an NFT is always 1; so, the weighted amount equals to the
//   'weight' (limited by 2^48).
// - The scaled amount of a UTXO representing a fungible token can be up to 2^64 - 1, but the
//   'weight' never exceeds 2^32 in this case.
//
// Edge-cases
// ----------
// The ZAssetTree design takes into account (i.e. support) the following edge-cases.
//
// ** ERC-1155 tokens **
// A token (with a particular external ID) on the ERC-1155 smart contract may behave as either a
// fungible or non-fungible token. Unlike an ERC-20 token, a fungible ERC-1155 token (like an NFT)
// has the external ID. Moreover, the same contract may issue both fungible tokens and NFTs.
//
// ** Token on multiple supported networks **
// If a token circulates on different networks, then multiple Leafs, with the distinct network and
// perhaps token contract address in each Leaf, can contain a ZAsset for the token. The Batch ID in
// each Leaf then will share the same 32 MSBs, while the 32 LSBs of the Batch ID will differ (hence
// the Batch ID will be unique).
// For "scaling" to properly work, the 'scale' in all these Leafs MUST be the same.
//
// ** Re-scaling (forking) ZAsset **
// If a token's price changes significantly, it might become impossible to adjust the 'weight' to
// remain within the allowed range. In such cases, the 'scale' may need to be adjusted. Since the
// the 'scale' for any NFT MUST be exactly 1, it may be done for a fungible token only.
// Since some UTXOs with the "old" ZAsset representing this token might remain unspent, the 'scale'
// in the "old" ZAsset's Leaf cannot be altered. Instead, a new ZAsset and the Leaf for it should
// be created, with the Batch ID and the 'scale' adjusted only. As a result, the same token on the
// same network may be represented by multiple ZAssets and their respective Leafs.
// Each ZAsset and its Batch then will have distinct IDs. Even though all these ZAssets represent
// the same token, circuits will treat them as different ZAssets due to their varying ZAsset IDs.
///
template ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth){
    signal input {uint64}           zAsset;      // ID of the ZAssets Batch
    signal input {uint168}          token;       // token smart contract type and address
    signal input {uint252}          tokenId;     // range for external IDs starts with this value
    signal input {uint6}            network;     // ID of a network ZAssets (UTXOs) may be spent on
    signal input {uint32}           offset;      // external ID range's ending value offset
    signal input {uint48}           weight;      // weighting factor
    signal input {non_zero_uint64}  scale;       // scaling denominator
    signal input                    merkleRoot;  // root of the ZAssetsTree
    signal input {binary}           pathIndices[ZAssetMerkleTreeDepth];
    signal input                    pathElements[ZAssetMerkleTreeDepth];

    assert(0 <= zAsset < 2**64);
    assert(0 <= network < 2**6);
    assert(0 <= offset < 2**32);
    assert(0 <= token < 2**168);
    assert(0 <= tokenId < 2**252); // special case since field-element bit range
    assert(0 <= weight < 2**48);

    component merkleVerifier = MerkleTreeInclusionProofDoubleLeaves(ZAssetMerkleTreeDepth);

    component hash[2];

    hash[0] = Poseidon(5);
    hash[0].inputs[0] <== zAsset;
    hash[0].inputs[1] <== token;
    hash[0].inputs[2] <== tokenId;
    hash[0].inputs[3] <== network;
    hash[0].inputs[4] <== ( offset * 2**64 ) + scale; // serialization

    hash[1] = Poseidon(2);
    hash[1].inputs[0] <== hash[0].out;
    hash[1].inputs[1] <== weight;

    merkleVerifier.leaf <== hash[1].out;

    merkleVerifier.pathIndices <== pathIndices;
    merkleVerifier.pathElements <== pathElements;

    // verify computed root against provided one
    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== merkleVerifier.root;
    isEqual.in[1] <== merkleRoot;
    isEqual.enabled <== merkleRoot;
}
