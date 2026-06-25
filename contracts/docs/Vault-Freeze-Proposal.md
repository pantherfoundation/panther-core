# Proposal: Freeze the v0 Vault and migrate to a Merkle-claim payout

## TL;DR

Upgrade the v0 `Vault_Proxy` on Polygon to a new implementation
(`VaultV0Frozen`) that:

- Permanently disables every existing entry/exit path through the v0 MASP
  (`PantherPool.exit()`, `PantherPool.generateDeposits()`).
- Replaces it with a Merkle-tree claim path: each advanced-staking reward
  recipient claims their ZKP and PNFTs directly from the Vault by submitting
  a proof against a single Merkle root that is published in a **follow-up**
  proposal.
- Time-locks any owner withdrawal of unclaimed residuals for 365 days from
  the moment the root is published.

This proposal contains a **single on-chain action** (one `upgradeTo` call).
It does **not** include the Merkle root — that comes later, once the
entitlement dataset is finalised post-execution.

---

## Background

Advanced staking on Panther was a 2022-2024 program that locked ZKP and a
PNFT reward into the v0 Multi-Asset Shielded Pool (MASP) for each staker.
Users withdraw via `PantherPoolV0.exit()`, which spends a UTXO commitment in
the Merkle tree and unlocks the underlying asset from the v0 `Vault`.

The program is being deprecated. Rather than leave users to interact with
the v0 MASP indefinitely (which carries operational cost and is not
compatible with the v1 architecture), the DAO is migrating to a simpler
direct-claim mechanism.

### Why the Vault and not PantherPool?

`PantherPoolV0.exit()` calls `VaultV0.unlockAsset(...)`, which is
`onlyOwner` against the immutable owner = `PantherPool`. Replacing the Vault
implementation so that `unlockAsset` reverts is sufficient to disable every
exit, because the call chain breaks one hop into the Vault.

This same upgrade also gives us a place to host the new `claim()` function,
eliminating the need for a separate distribution contract and re-using the
ZKP / PNFTs already held by the Vault rather than sweeping them out.

---

## On-chain action

### Single transaction

| Field    | Value                                                                   |
| -------- | ----------------------------------------------------------------------- |
| Target   | `0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9` (`Vault_Proxy` on Polygon) |
| Value    | `0`                                                                     |
| Method   | `upgradeTo(address)`                                                    |
| Argument | `0x31f63DD9Dd1ba6A4b265A31686139Af7F1cdf923`                            |
| Calldata | `0x3659cfe6` + 32-byte-padded impl address                              |

---

## Storage layout safety

| Implementation        | Storage slots used                                                                    |
| --------------------- | ------------------------------------------------------------------------------------- |
| `VaultV0` (current)   | none — only immutables (`OWNER`) in bytecode                                          |
| `VaultV0Frozen` (new) | slot 0 `_reentrancyStatus`, 1 `root`, 2 `claimed`, 3 `nftsClaimed`, 4 `claimOpenedAt` |

The current proxy storage at slots 0–4 is uninitialised (all zero), which is
exactly the correct initial state for the new implementation:

- `_reentrancyStatus = 0` → treated as not-entered (handled explicitly by
  `NonReentrant.sol`: "when `_reentrancyStatus` is 0, it does not revert").
- `root = 0` → `claim()` reverts with `"VFrozen: not open"`. Correct: the
  claim path is intentionally closed until the follow-up proposal sets it.
- `claimed` mapping → empty.
- `nftsClaimed = 0`, `claimOpenedAt = 0` → fresh.

No storage migration is required.

---

## Effects on users at execution time

### Disabled immediately

- `PantherPoolV0.exit()` reverts with `"VFrozen: frozen"`. No advanced
  staker can withdraw via the v0 MASP path anymore.
- `PantherPoolV0.generateDeposits()` reverts with `"VFrozen: frozen"`. No
  new deposits/UTXOs can be created in the v0 MASP.
- `PantherPoolV0.commitToExit()` still callable (it has no time gate in the
  pool contract) but pointless — the eventual `exit()` reverts. The frontend
  should be updated to hide this path.

### Not yet enabled

- `VaultV0Frozen.claim(zkpAmount, nftCount, claimNft, proof)` reverts with
  `"VFrozen: not open"` until the DAO publishes the Merkle root via the
  follow-up proposal.

### Unaffected

- Classic-staking deposits / withdrawals (`Staking.unstake()` on the v0
  Staking contracts) continue to work normally on both Ethereum and
  Polygon. Principal ZKP held by the Staking contracts is not touched.
- Token contracts (PZkpToken, PNftToken) are not modified.
- v1 protocol contracts are not modified.

### Why we don't need to also call `disableTerms`

On-chain verification of `Staking.terms(...)` for every known advanced
stake type on both chains shows:

```
Polygon — all 4 advanced types past `allowedTill` (latest: 2024-03-10) → BLOCKED
Mainnet — 4 of 5 advanced types past `allowedTill` → BLOCKED
Mainnet — stake type 0xf51d0a02 still open, but `isRewarded = false`:
          new stakes of this type do not call RewardMaster → no UTXOs are
          minted in the v0 MASP → no impact on the Vault.
```

New advanced-staking is therefore impossible regardless of this proposal.
`disableTerms` is unnecessary.

---

## The follow-up proposal (out of scope here)

A **separate** proposal will commit the Merkle root that governs who can
claim how much:

| Field    | Value                          |
| -------- | ------------------------------ |
| Target   | `Vault_Proxy` (`0x5E7Fda…6c9`) |
| Method   | `setRoot(bytes32)`             |
| Argument | `<final Merkle root>`          |

The root is generated off-chain from the reconstruction script
(`contracts/scripts/advanced-stakes-report/`), which:

1. Indexes every `RewardGenerated` (Polygon ARC) and every `Nullifier` (v0
   PantherPool) event from chain history.
2. Aggregates per-user entitlement: `zkpAmount` = sum of unclaimed
   `RewardGenerated.zkp`, `nftCount` = count of unclaimed PNFT-bearing
   rewards.
3. Verifies on-chain that `Σ zkpAmount == Vault.ZKP.balanceOf` and
   `Σ nftCount == 2000` (the total PNFTs minted to the Vault — confirmed
   by spot-checking `NFT.ownerOf(1)`, `NFT.ownerOf(1000)`, and
   `NFT.ownerOf(2000)`).
4. Outputs the root and a per-user proof file pinned to IPFS for the
   claim frontend.

`setRoot` is callable exactly once (one-shot guard in the contract). It
also starts the 1-year clock for `ownerSweepErc20` / `ownerSweepNft`.

---

## Claim mechanics (after the follow-up proposal)

```solidity
function claim(
  uint256 zkpAmount,
  uint16 nftCount,
  bool claimNft,
  bytes32[] calldata proof
) external nonReentrant;
```

- `zkpAmount` and `nftCount` are the entitlement values committed in the
  user's Merkle leaf.
- `claimNft = true` → the contract dispenses `nftCount` PNFTs from a
  sequential cursor (next id = `FIRST_NFT_ID + nftsClaimed`).
- `claimNft = false` → ZKP is transferred but no PNFTs; the cursor is not
  advanced. Useful for users who only want their ZKP. Same address cannot
  later claim its PNFTs (the `claimed` flag is one-shot).
- Anti-reentrancy via `nonReentrant`, CEI ordering (`claimed[msg.sender]`
  and `nftsClaimed` written before any token transfer), `transferFrom`
  (no callback) for PNFTs.

UI helpers exposed by the contract:

- `isClaimOpen()` — `bool`
- `nftsRemaining()` — `uint16`
- `nextNftId()` — `uint16`
- `claimed(address)` — `bool`
- `verifyClaim(user, zkpAmount, nftCount, proof)` — `bool`
- `isClaimable(user, zkpAmount, nftCount, claimNft, proof)` — `bool`
- `sweepUnlocksAt()` — `uint256` (unix time when owner sweep unlocks)

---

## Owner sweep (residual recovery)

After 365 days from `setRoot`, the DAO multisig may call:

- `ownerSweepErc20(token, to, amount)` — recover residual ERC-20 (typically
  unclaimed ZKP) to any address.
- `ownerSweepNft(to, tokenIds[])` — recover residual PNFTs.

Both are `onlyOwner` and guarded by `afterClaimWindow`. Before `setRoot`
they revert with `"VFrozen: claims not open"`; inside the 365-day window
they revert with `"VFrozen: too early"`.

---

## Risks and mitigations

| Risk                                                                                                                        | Mitigation                                                                                                                                                                                                                                                                                               |
| --------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Bug in the new implementation locks all funds.                                                                              | Reviewed against the user's pre-existing `VaultV0WithClaim.sol` draft; comprehensive unit test suite (46 tests passing) covering happy paths, every revert branch, time-lock boundaries, multi-user sequential claims, and the `claimNft = false` path. Contract source and tests committed to the repo. |
| MEV / front-run race between proposal queue and execution: someone exits via `PantherPool.exit()` before the upgrade mines. | The reconstruction script is **re-run after execution** to capture any last-minute exits. The Merkle root in the follow-up proposal reflects the truly final state.                                                                                                                                      |
| Owner key (multisig) compromise.                                                                                            | All privileged actions (`setRoot`, sweeps) require the DAO multisig. `setRoot` is one-shot; once committed, the root cannot be changed without a new implementation upgrade. Sweeps are additionally time-locked for 365 days.                                                                           |
| Smart-contract wallets that don't implement `IERC721Receiver` are bricked from claiming PNFTs.                              | The contract uses `transferFrom` (not `safeTransferFrom`), so contract wallets are unaffected. Users who don't want PNFTs at all can pass `claimNft = false`.                                                                                                                                            |
| Storage collision after upgrade.                                                                                            | Verified: `VaultV0` has zero storage variables; all `VaultV0Frozen` slots start uninitialised, which equals the correct fresh state for each variable.                                                                                                                                                   |
| Reentrancy via PNFT transfer callbacks.                                                                                     | `transferFrom` has no callback. `claim()` is also `nonReentrant` and follows CEI (`claimed` flag and `nftsClaimed` cursor written before transfers).                                                                                                                                                     |

---

## Verification checklist before voting

- [ ] `VaultV0Frozen` implementation address from the deployment script
      matches the address in the proposal calldata.
- [ ] Contract is verified on Polygonscan; the bytecode matches
      `contracts/contracts/protocol/v0/VaultV0Frozen.sol` at the commit
      referenced in this proposal.
- [ ] Test suite passes (`npx hardhat test test/protocol/VaultV0Frozen.test.ts`,
      46 passing).
- [ ] `OWNER` immutable on the deployed implementation equals the DAO
      multisig (`0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0`).
- [ ] `ZKP_TOKEN` and `NFT_TOKEN` immutables match the production
      PZkpToken / PNftToken addresses.
- [ ] No second-order references: `git grep VaultV0Frozen` returns only the
      contract, its test, the deployment script, and this document.

---

## Addresses summary

| Name                                   | Address                                      |
| -------------------------------------- | -------------------------------------------- |
| Vault proxy (target of `upgradeTo`)    | `0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9` |
| DAO multisig (proxy admin + new owner) | `0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0` |
| PZkpToken                              | `0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC` |
| PNftToken                              | `0xE5da4955cBC480Eb9Bf9534def229F9D8339eE6d` |
| PantherPoolV0 proxy (rendered inert)   | `0x9a423671e9Cde99Ae88853B701f98ca9e136877B` |
| `VaultV0Frozen` implementation         | _(filled in after deployment)_               |
