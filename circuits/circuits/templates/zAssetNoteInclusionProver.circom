//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "./merkleTreeInclusionProof.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
//    ## ZAsset tree/leaf logic
//
//    ZAsset
//    ------
//    ZAsset is a representation of a token inside the MASP.
//
//    Batch of ZAssets
//    ----------------
//    "Batch" is a set including one or more (up to 2^32) tokens having common params.
//    Tokens get registered/enabled/disabled in the protocol via Batches.
//
//    In case of a fungible token, or a single NFT with a unique tokenId, a Batch
//    includes a single token only (e.g. a Batch for the $ZKP token only).
//    However, a Batch may include many NFTs - all of them MUST be on the same token
//    contract but have different `tokenId` from a range Batch parameters define.
//
//    ZAssetTree
//    ----------
//    Binary Merkle tree with leafs being commitments to parameters of Batches.
//
//    ZAssetTree Leaf
//    --------------
//    Every Leaf is a commitment to parameters of a Batch the Leaf represents:
//    ```
//    zAssetLeaf = Poseidon([
//        Poseidon([
//            zAssetsBatchId, // {uint64} `zAsset` in circuits
//            tokenAddrAndType,// {uint168} `token` in circuits
//            startTokenId,   // {uint252} `tokenId` in circuits
//            network,        // {uint6} same name in circuits
//            2^64 * tokenIdsRangeSize + scale
//                            // tokenIdsRangeSize {uint32} `offset` in circuits
//                            // scale {non_zero_uint32}
//        ]),
//        weight              // {uint32}  same name in circuits
//    ])
//    ```
//    (Note comments on `zAssetsBatchId`, `scale`, `weight` in other sections).
//
//    `tokenAddrAndType` - token type (ERC-20|721|1155) {uint8} followed by the token
//    contract address {uint160}.
//
//    `tokenIdsRangeSize`, together with `startTokenId`, defines a range of values the
//    tokenId of a token in a Batch may have:
//    `startTokenId =< tokenId =< startTokenId+tokenIdsRangeSize`.
//    > `tokenIdsRangeSize` MUST be 0 for a Batch with one token (a fungible token, or
//    > a NFT having a particular tokenId).
//    > In other words, `tokenIdsRangeSize` for a Batch with an ERC-20 token MUST be 0.
//
//    `startTokenId` sets a starting value for the range the `tokenId` of a token in
//    the Batch MUST be in. See notes on `tokenIdsRangeSize` as well.
//    > `startTokenId` MUST be 0 for an ERC-20 token.
//
//    Once registered, Leaf's parameters MUST be immutable, except for:
//    - `weight` which may be (often) changed
//    - `network` MUST be set to a special value if Batch asset(s) are disabled,
//       and the previous value MUST be restored on enabling the asset(s) back.
//
//
//    zAssetsBatchId (Leaf parameter)
//    -------------------------------
//    (Circuits does not have an input signal for `zAssetsBatchId`. Instead, circuits
//    extract MS bits from the `zAssetId` signal to get `zAssetsBatchId`).
//    `zAssetsBatchId` is the batch's ID - one of parameters in a ZAsset Tree's leaf.
//    It is NOT the index of the Batch Leaf in the ZAssetsTree.
//    Moreover, there may exist a few Leafs having the same `zAssetsBatchId` (in case
//    the same token circulates on different networks, for example).
//    `zAssetsBatchId` is a 64-bit number, 32 MS bits of which are assigned by a smart
//    contract's counter (starting with 0) on registration of a Batch. 32 LS bits are
//    unused (in this version) and MUST be set to 0.
//
//    > Examples:
//    > 1. $ZKP (ERC-20). MUST be in the 1st Batch with `zAssetsBatchId` of 0.
//    > 2. ERC-20 token in the 10th Batch with `zAssetsBatchId` being (10-1)*2^32+0.
//    > 3. NFT with tokenId 56 in the 11th Batch with `zAssetsBatchId` (11-1)*2^32+0
//    >    (`startTokenId` being 56, and `tokenIdsRangeSize` being 0)
//    > 4. 33 NFTs with the tokenId's from 167 to 199 in the 12th Batch.
//    >    `zAssetsBatchId` is (12-1)*2^32+0
//    >    (`startTokenId` being 167, and `tokenIdsRangeSize` being 33).
//
//    zAssetId (UTXO parameter)
//    -------------------------
//    (Circuits expose the private signal `zAssetId` for it).
//
//    `zAssetId` is a UTXO parameter which specifies the token the UTXO represents:
//    circuits treat UTXOs with different `zAssetId` as ones representing different
//    asset/token.
//    It always refers to a particular token rather than a Batch.
//
//    `zAssetId` is a 64-bit number, 32 MS bits of which repeat the 32 MS bits from
//    `zAssetsBatchId` of the Batch the token belongs to.
//    32 LS bits for an ERC-20 token MUST be zeros. For an NFT, these bits contain
//    the UINT number, which being added to the `startTokenId`, gives the tokenId.
//
//    !!! For any ERC-20 token, `zAssetsId` is the same as `zAssetsBatchId` of the
//    Batch the token belongs to.
//
//    > Examples:
//    > 5. `zAssetId` for $ZKP MUST be 0.
//    > 6. The ERC-20 token from Example 3) has the `zAssetId` of (10-1)*2^32+0.
//    > 7. NFT from the Example 3) has `zAssetId` of 10*2^32+0.
//    > 8. NFT from the Example 4) with `tokenId` 173 has `zAssetId` of 11*2^32+6.
//
//    Amount Scaling
//    --------------
//    Amounts in UTXOs (ZK-circuits operate with) are "scaled" relatively to amounts
//    token smart contracts operates in:
//    ```
//    scaledAmount = tokenContractAmount / scale
//      where, `scale` is the parameter of the ZAssetTree Leaf.
//    ```
//    Scale MUST be non-zero.
//    For NFTs `scale` MUST be 1.
//    Circuits expect `scale` to be in the range [1..2^32-1], and scaled amounts
//    to be less than 2^64.
//
//    > Example:
//    > Let `scale` for $ZKP be, say, 1e+12. $ZKP has 18 decimals.
//    > So, 0.5 $ZKP is represented as:
//    > - 0.5e+18 (=0.5 * 1e18) - the amount the token contract stores
//    > - 0.5e+12 (=0.5 * 1e+18/1e+12) - the amount a UTXO stores.
//
//    !!! Technically, a particular `zAssetId` value may match to `zAssetsBatchId`
//    values registered for/in many Batches/Leafs (use-case for this is unclear).
//    For the amount "scaling" to properly work in Circuits, `scale` in all Leafs
//    the `zAssetId` may match to MUST be identical.
//
//    Amount Weighting
//    ---------------
//    Circuits compute transaction limits and rewards based on the "weighted" amounts.
//    A unit of the the weighted amount should worth approximately the same monetary
//    (USD) value for any token, independent of token prices.
//    To obtain it, a factor called `weight` is used to derive the weighted amount:
//    ```
//    weightedAmount = scaledAmount * weight
//    ```
//    `weight` is assigned for every Batch and assumed to be updated time after time in
//    order to (approximately) adjust for token market price changes.
//    Circuits expect `weight` to be in the range [0..2^64-1], and weighted amounts to
//    be less than 2^96.
//
//    Notes on ERC-1155 tokens
//    ------------------------
//    Tokens with different tokenId on the same ERC-1155 token contract may be
//    either fungible tokens, or an NFT, or a combination of both.
//
//    If a token with a particular tokenId represents a fungible token, then:
//    - It SHOULD be included in a separate Batch
//    - Just like for ERC-20, `scale` MAY be any number in the range
//    - Unlike for ERC-20, `startTokenId` MUST contain the tokenId rather than 0
//    - 32 LS bits of `zAssetId` SHOULD be 0.
//
//    Technically, a few fungible tokens with consecutive tokenId(s) may be in the
//    same Batch, the use-case for which is unclear. If it is so:
//    - `startTokenId` MUST contain the smallest tokenId value
//    - 32 LS bits of `zAssetId` MUST contains the difference between the tokenId and
//      the `startTokenId`.
//
//    If a token with a particular tokenId represents an NFT (with total supply of 1):
//    - it MAY be included in a separate Batch, or MAY be joined by a Batch with other
//    - NFTs on the same contract having consecutive tokenId(s)
//    - `scale` MUST be 1
//    - `startTokenId` MUST contain the tokenId (or the smallest tokenId value,
//      if many NFTs are included in a Batch) rather than 0
//    - 32 LS bits of `zAssetId` MUST contains the difference between the tokenId and
//      the `startTokenId`.
//
// Another need for the update, found computing initial values of token parameters, is as follows.
// We need the assetWeight to become uint48, not uint32.
//
// 48 bits may be required for an expensive NFT:  the scaledAmount for an NFT is always 1; so, the weightedAmount of a UTXO with any NFT is always and exactly the assetWeight.
//
// Please note, the product (multiplication)  scaled_amount * assetWeight does not exceed 48 bits for an NFT (as the scaledAmount is always 1).
// On the other hand, for a fungible (ERC-20) token, which scaledAmount may occupy up to 64 bits, the assetWeight never exceeds 32 bits; and the product does not exceed 96 bits.
// So, although, technically, a product scaled_amount * assetWeight  (uint64 * uint48), i.e. the weightedAmount may exceed uint96, we do not have such a use-case, where both factors are simultaneously high enough for the product to exceed 96 bits. Therefore, the (existing) constraint on the weightedAmount of 96 bits works fine for all use-cases.
//
// tldr;
// Explanation here
// https://docs.google.com/spreadsheets/d/1AZz0gO9M30W_JkfTW28Uf-CRknDoRKdvKZzvf35IDEg/edit?gid=0#gid=0
// (please note v:19 on the "Scaling & Weighting")
template ZAssetNoteInclusionProver(ZAssetMerkleTreeDepth){
    signal input {uint64}           zAsset;      // 64 bit ( was 160 )
    signal input {uint168}          token;       // 168 bit - ERC20 address
    signal input {uint252}          tokenId;     // 256 bit - NFT-ID/Token-ID, can be zero in-case some LSB bits from zAssetID is used for NFT-count
    signal input {uint6}            network;     // 6 bit - network-id where UTXO is spent (UTXO-in)
    signal input {uint32}           offset;      // 0..31 bit number
    signal input {non_zero_uint48}  weight;      // 48 bit
    signal input {non_zero_uint64}  scale;       // 64 bit
    signal input                    merkleRoot;
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
