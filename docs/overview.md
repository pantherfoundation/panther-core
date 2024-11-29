---
title: zAsset UTXO model
warn: Updates to the Protocol that impact this page should be replicated to public docs https://docs.pantherprotocol.io/docs/learn/utxos >> Note that the assumed readership there is less technical than here, please adjust language and approach accordingly
comment: page to provide an overview of the zAsset UTXO model
todo: IF this page can be reviewed, approved, and merged, then deprecate the content in the Shielded Pool (see source) document in favor of markdown in-repo documentation
source: Vadim && https://docs.google.com/document/u/1/d/1BTWHstTgNKcapOe0PLQR41vbC0aEDYmbBenfzTq8TVs/
---

## TL;DR

- Spender encrypts a message to recipient that is published on-chain
- All zAccount holders scan the chain for UTXO commitments and attempt to read the message
- Only the intended recipient, the account holding the cryptographic key, may read the message and assume spend rights to a UTXO
- The key is derived from the recipient's public key and is unique to each UTXO commitment

## Introduction

An essential requirement of Panther's Shielded Pools is to ensure the untracability of transactions to stakeholders who do not hold the correct keys. To achieve this, the mainnet beta Protocol supports non-interactive transactions. That is, the spender can pass assets to the receiver's zAccount using the receiver's public read key and the public root spending key available on an lookup registry maintained by the smart contract.

It is the commitment of a UTXO data package on-chain that provides the immutable record of a transaction. Within Panther Protocol UTXOs are used to represent:
	- Digital assets (zAssets)
	- zAccounts

However, it is only possible to access data contained within the UTXO by providing the correct cryptographic solution. To spend or open a zAsset UTXO the spender must provide the unique private key. This requirement for a unique private key for each UTXO contributes to the Protocol's privacy layer

> A UTXO is the hash of a data package committed to a leaf of a Merkle Tree. The commitment of a UTXO on-chain and the data contained therein, is verifiable thanks to a SNARK proof generated at the time of the commit.
>
> UTXOs are used in different ways within the Protocol, which makes the "unspent transaction" a misnomer in certain instances.


## Shielded Pool contract responsibilities on spend

The Shielded Pool contract performs several checks when Alice sends a UTXO to Bob, it verifies:
- There is no double-spend of the UTXO
> nullifierHash is calculated correctly and has not been used before
<!-- todo: ask do we include that there is also a nullifier public key which prevents double spend {you get the hash then to cryptographic computation using nullifier private key } -->
- The ZK proof:
	- the opening of the UTXO commitment is correct
	- the Merkle proof is correct
	<!-- the root should == merkle root is correct and the merkle path is correct commitment is == that the path from leaf to root is correct -->
	- the derived identity is entitled to spend the UTXO
		- Child Public Spending Key is derived from the Child Private Spending Key
		- Child Private Spending Key is the same input used in the opening of the UTXO commitment

## zAsset transfer: UTXO spend

zAssets represent digital assets as UTXOs. Every UTXO has one “owner” or zAccount able to spend it. This is achieved by including a public (spending) key in the generation of the UTXO commitment, for which the corresponding private (spending) key is only known by the recipient.

A zAsset transfer is a non-interactive, asynchronous spend/receive event that involves two UTXO models, the zAsset and the zAccount.

During a spend event, the zAccount holder is either receiving an input UTXO, as in they are the recipient of a digital asset; or they are creating an output UTXO, as in they are spending/sending a digital asset.

> When Alice transfers a UTXO to Bob, she transfers the UTXO's read and spend rights to Bob. This means that only Bob's zAccount may open and read the UTXO or spend the UTXO.

To access the receiver’s public keys, the sender's zAccount looks up the user zAccount registry.

> On zAccount activation, this registry establishes a link between the public root spending key, public reading key, and an EOA (externally owned account) i.e. a wallet address associated with the user. This allows a non-tracable method for the sender to access the receiver's data.

The Shielded Pool supports the spending and creation of multiple UTXOs all within a single transaction using a single proof. Let's consider the outcome of a spend event that results in the transfer of just 1 zAsset UTXO.

As a result of the spender initiating a zAsset transfer to a different zAccount, at least 2 new UTXOs are committed to the Merkle Tree:

- Token of transaction: zAsset UTXO created to the value of the transfer amount
> With a unique key based on the intended recipient's public key
- Token of transaction: zAsset UTXO representing any change, if a 0 amount i.e. no "unspent" value remains, then no UTXO is created
> If Alice has a UTXO representing 5 zETH and sends Bob 2 zETH, the unspent amount is represented by at least 1 UTXO to the value of 3 zETH
<!-- following line probably incorrect todo! zAccount is (probably) not reflecting asset balance-->
- zAccount UTXO: the sender's zAccount UTXO is updated to deduct the value of asset sent from balance, fee deduction in zZKP, and an increment to their PRP reward

As a result of the receiver (asynchronously) unlocking the UTXO with their key:
<!-- following line incorrect, needs fixing todo -->
- zAccount UTXO: receiver's zAccount UTXO is updated to reflect the value of asset received

In the case that the sender chose to use a Relayer service to increase the privacy set of the transaction, further UTXO updates are implemented to pay the Relayer fee.


## zAsset Cryptography

Every zAsset UTXO has one “owner” or zAccount able to spend it. This is achieved by including a unique public (spending) key in the generation of the UTXO commitment, for which the corresponding private (spending) key is only known by the recipient.

In order to spend a UTXO the owner needs to prove (in Zero-Knowledge) that they hold the spending private key.

A high-level overview of how the Protocol follows.

## High-level overview of Panther's UTXO cryptography

> The following conventions are applied to formulae:
> - lowercase letters in formulae bellow denote prime field elements ("scalars") - i.e. private keys
> - capital letters denote points on the elliptic curve - i.e. the public keys
> - '*' denotes the multiplication of an elliptic curve point by a scalar, i.e. scalar multiplication


- The Protocol uses a shared symmetric key for encryption/decryption of messages with secrets
- Secrets. `M` are UTXO's "opening values" for recipients *and* data for spenders to track past transactions
- Messages passed to the smart contract are encrypted:
	- spender to receiver
	- spender to self
	<!-- todo: add messages to Escrow once confirmed -->
- Sender publishes the Ephemeral key, `E` and ciphertext `M'` on-chain &mdash; formalizing a transaction
- Recipient scans chain to extract `M` (from `M'` using `E`) to take ownership of a UTXO
- Spender can re-create history by decrypting messages to self, `M'`
- Although spender knows the UTXO's public key, only the recipient who holds the root spending private key may spend the UTXO

Let's take a closer look at how the cryptography behind this Protocol is implemented.

## Panther Protocol keys

A "key pair" is a pair composed of a private key and its corresponding public key.

The private key is a big integer ("scalar") from the prime field defined by the Baby Jubjub elliptic curve.

The public key, `P` corresponding to the private key, `p` is a point on the curve, such that the following equation holds:

> `P` = `p` * `G`

Where, `P` and `p` are the public and private keys, and `G` is the generator of the group of elliptic curve points.

The, so called `Base8` point is used as the generator. This point generates a "commutative group" of curve points that cryptographers call the "Baby Jubjub subgroup".

The [ECDH key agreement protocol](../glossary.md#ecdh) (over the Baby Jubjub elliptic curve) is used to share the symmetric key and to derive the spending keys of UTXOs.

The following key pairs are essential to the transfer of zAssets in the form of UTXO updates:

1. Recipient reading key pair (`w`,` W` = `w` * `G`): allows the recipient to decode messages with opening values of UTXOs, i.e. knowledge of the private key is needed to decrypt a message.
2. Root spending key pair (`s`, `S` = `s` * `G`): enables spending of a UTXO by the owner, i.e. no matter who generates a UTXO only the holder of the private key may spend the UTXO.

> The term "root" applies as spending keys for UTXOs are "derived" from this key pair.

3. Nullifier key (`n`, `N` = `n` * `G`): required in order to generate the nullifiers for UTXOs.

> This key enables compliance, by encoding the nullifier so that information in the **Data Safe** may reveal whether the UTXO has been spent.

Next, let's consider how spending and encryption keys are derived.

### Creating a new UTXO

When a zAsset is spent, an output, i.e. a new UTXO is created.

1. Spender selects two randoms, `r` and `e`, to derive the spending and message encryption keys.
2. Spender derives the spending public key `S'` for the new UTXO from the recipient's root spending public key `S` and the random `r`:
> `S'` = `r` * `S`
3. Spender creates an ephemeral key using the random (`e`) from Step 1:
> `E` = `e` * `G`
4. Spender creates the shared key, `K` to encrypt the message to the recipient with, based on recipient's public reading key, `W` and the random, `e`:
> `K` = `e` * `W`
5. Spender composes the message to the recipient, `M` and encrypts the message into the ciphertext, `M'`.

>5.1 Message composition.
>The message, `M` contains the information needed to spend the UTXO: random, `r` required for the recipient to generate the spending key, `S'` and other opening values (such as `zAssetId` and the value the UTXO represents).
>
>5.2 Message encryption.
>The spender encrypts the message to the recipient with the shared key, `K` applying the symmetric encryption (applying the method `AES-128-cbc`):
> `M'` = Enc(`M`, `K`)

6. Spender calls the Shielded Pool contract to publish the new UTXO as well the encrypted message to the recipient.

>6.1 Publishes the ephemeral key, `E` and the ciphertext `M'`.
>
>6.2 Using the same encryption key derivation method, but with own reading key instead of the recipient's reading key, the spender encrypts the message "to self".
> This encrypted message (which only the spender may decrypt) contains data required to reconstruct an audit trail of the spender's transactions.

<!-- only the spender may decrypt?? -- I thought that the Zone Manager had to have visibility over data safe information too? todo return to this -->

#### Taking ownership of a UTXO

The following steps detail how a recipient is able to take ownership of the input UTXO.

#### 1. Scan chain for ciphertexts

Each zAccount holder behaves as it is a potential recipient and scans the chain for ciphertexts, `M'` and ephemeral keys, `E`.

#### 2. Attempt to decrypt every ciphertext

##### 2.1 Compute the shared key, `K`

> `K` = `w` * `E`

Note, if the spender encrypted the message with the recipient's public reading key (i.e. the message is intended for the recipient), the recipient derives the same shared key that the spender used:

> `K` = `w` * `E` = `w` * (`e` * `G`) = `e` * (`w` * `G`) = `e` * `W`

#####  2.2 Decrypt the ciphertext using that key

> `M` = Dec(`M'`, `K`)

##### 2.3 Analyze whether the decrypted message, `M` is meaningful

If an encrypted message (i.e. the ciphertext and the ephemeral key) was intended for a different recipient, and thus the non-recipient computed the wrong encryption key, the decryption algorithm still returns some random (meaningless) decrypted text. However, the true recipient can easily distinguish if the decrypted text, `M` contains properly formed or meaningless data.

> So,
> IF `M` is invalid, message is ignored.
> IF `M` is valid, recipient extracts from `M` the random, `r` and other opening values required to spend the UTXO.

##### 2.4 Derive the private spending key for the UTXO

The recipient derives the private spending key for the UTXO:

> `s'` = `r` ∙ `s`
> here, '∙' denotes multiplication of integers (in the prime field).

Note, that the private spending key derived this way indeed corresponds to its public key that the spender derived:
> `S'` = (`r` ∙ `s`) * `G` = `r` * (`s` * `G`) = `r` * `S`

<!-- todo: does not cover account bal update of zAccount does it ? -->

This method provides an efficient encryption/decryption mechanism, and a unique spending public key which is unlinkable to other transactions by the same recipient, even given that E is publicly accessible on-chain.


<!-- agreed and changed
"ownership updates to UTXO" seems to be a misleading wording, since user does not necessarily create a new UTXO (for another user) identical to the spent one, in which case the "ownership update" allegory could work. Instead, the user may spend two UTXOs to create new one ("joining"), or create two new UTXOs with half of the spent UTXO's value each ("splitting"), and many more similar combinations.
These combinations can hardly be called "ownership updates" -->
