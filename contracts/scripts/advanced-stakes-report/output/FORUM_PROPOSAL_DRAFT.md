# Forum Draft — Proposal 2: Open the advanced-staking claim window

> Pre-vote forum discussion for the second of two proposals that wind down
> v0 advanced staking. See [Proposal 1 discussion](https://snapshot.org/#/s:pantherprotocol.eth/proposal/0xb2711837bf3b2071390a501d6b9bec703077f927b79ded483aff44844bbe563c/discussion)
> for context on the architecture chosen.

## TL;DR

Proposal 1 froze the v0 Vault on Polygon and disabled exits from the v0
MASP. Proposal 2 opens the claim window so every eligible advanced staker
can withdraw their owed ZKP and PNFTs directly from the Vault in a single
transaction. Before the claim window opens, the Vault is topped up so it
holds exactly what is owed: principal + the 10% APY return previously
promised to stakers who left their position locked.

Funding for the APY-return shortfall (392,496.05 ZKP) comes from a **new
vesting pool** created in the existing `VestingPools` contract on Ethereum
mainnet, sized exactly to the gap and released through the foundation
multisig.

The final step of this proposal updates the on-chain root that turns the
claim window on. The full claim list (one entry per eligible staker, with
the proof needed to withdraw) is published on IPFS at CID
`QmXjozQCksvwrPHGivRJqRDhmatJ8Gh3Fb33jYc7BkSSzN` so it can be independently
verified before the vote. The moment this proposal executes, the frontend's
claim page becomes active and stakers can withdraw their entitlements.

---

## What the proposal does

The execution spans both chains. It can be packaged as a single forum vote
that authorises the multisig to perform the following steps in order:

### Phase A — Ethereum mainnet

1. **Create a new vesting pool** inside the existing `VestingPools`
   contract (`0xb476104aa9D1f30180a01987FB09b1e96dDCF14B`). The pool is sized
   exactly to the 392,496.05 ZKP gap, with the foundation multisig as the
   pool wallet, and is marked as adjustable so the start time can be moved
   later. Because a DAO proposal takes roughly 3 days from submission to
   execution, the pool's `start` parameter is intentionally set to a date in
   the following month, so that the requirement "start ≥ now at execution
   time" is comfortably satisfied no matter exactly when the proposal is
   executed.

2. **Move the pool's start time into the past** with `updatePoolTime`. The
   new `start` is set to a date before the proposal execution and the
   vesting duration stays at 1 day, so the entire allocation is immediately
   unlocked. This is bundled into the same proposal and runs right after
   step 1.

3. **Release the full pool allocation** to the foundation multisig on
   Ethereum.

4. **Bridge the released ZKP straight into the Vault on Polygon** through
   the canonical Polygon PoS bridge. The foundation multisig approves the
   ERC-20 predicate and calls `depositFor` on the RootChainManager, with
   the **Vault proxy (`0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9`) as the
   recipient**. Standard checkpoint timing applies — the tokens land
   directly in the Vault roughly 30 minutes later, with no intermediate
   hop on Polygon.

### Phase B — Polygon

1. **Drain the AdvancedStakeRewardController's ZKP balance into the Vault.**
   The AdvancedStakeRewardController still holds 1,748,708.47 ZKP that was
   reserved for advanced-staking rewards but was never paid out. The
   contract's reward period ended on 2024-05-09, so the `rescueErc20` path
   is already unlocked — the foundation multisig calls it directly to
   withdraw the entire balance into the Vault.

2. **Update the on-chain root** that controls the claim contract. This is
   a one-shot setter on the Vault — once updated, it cannot be changed
   again. Setting the root also starts a 1-year clock; after that clock
   expires, the foundation can sweep any residual that hasn't been claimed.

All of the above (Phase A + Phase B) is executed atomically as a single
DAO proposal. The 392,496.05 ZKP from Phase A step 4 is bridged directly to
the Vault as recipient; the Polygon PoS bridge delivers asynchronously
(~30 minutes after the L1 checkpoint), independently of when the on-chain
root is set. By the time stakers actually call claim, the Vault holds
exactly **9,577,878.27 ZKP** (principal + full APY return) plus the 2,000
PNFTs that have been there since the freeze.

---

## Numbers

|                                                 | Value                                          |
| ----------------------------------------------- | ---------------------------------------------- |
| Eligible addresses                              | **1,235**                                      |
| ZKP — unclaimed principal                       | 7,436,673.75 ZKP                               |
| ZKP — 10% APY return                            | 2,141,204.52 ZKP                               |
| **ZKP — total to be claimed**                   | **9,577,878.27 ZKP**                           |
| PNFTs — to be claimed                           | **2,000**                                      |
| Vault ZKP balance pre-execution                 | 7,436,673.75 ZKP (= principal exactly)         |
| AdvancedStakeRewardController ZKP pre-execution | 1,748,708.47 ZKP                               |
| Shortfall after the controller is drained       | **392,496.05 ZKP** (sourced from the new pool) |
| Vault NFT balance pre-execution                 | 2,000                                          |

---

## The 10% APY return — recap

Each leaf-id (stake position) that was NOT exited before the freeze receives
an additional payout on top of its ZKP principal, calculated as 10% per
year of the time the position was held. The cut-off date for accruing this return is fixed
at **2026-05-31** (the day proposal 2 is drafted). PNFTs do not earn any
APY — they are returned as-is.

---

## How the claim works (already deployed)

The frozen Vault implementation already on Polygon provides a single
`claim` function. Each eligible address calls it once with their entitled
ZKP amount, PNFT count, and a Merkle proof. The ZKP is transferred directly
to the staker and the PNFTs are dispensed sequentially from the Vault's
inventory. After the call, the address is marked as claimed and cannot claim
again.

The Vault's `setRoot` call in Phase B step 2 is the single switch that
turns the entire claim flow on.
