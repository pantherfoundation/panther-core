# PIP-38 — Action Brief for the Cross-Chain Proposal Generation Agent

> One-page reference. Use this together with:
>
> - `contracts/tasks/GOVERNANCE.md` — wrapping patterns (Modes A / B / C, FxRoot, MaticBridgeModule).
> - `contracts/test/protocol/PIP38EthereumActions.forked.spec.ts` — Ethereum fork simulation; on success writes `contracts/PIP-38-ethereum-actions.json`.
> - `contracts/test/protocol/PIP38PolygonActions.forked.spec.ts` — Polygon fork simulation; on success writes `contracts/PIP-38-polygon-actions.json`.

## What PIP-38 does

Wind down the v0 advanced-staking program in one atomic proposal:

1. Mint **5,492,496.05 ZKP** on Ethereum from a new VestingPools pool.
2. Split it: **392,496.05 ZKP** → Polygon Vault (covers the 10% APY-return shortfall for claimers); **5,100,000 ZKP** → Base ecosystem-rewards deployer wallet on Ethereum (the L1→Base bridge is done manually, outside this proposal).
3. Drain `AdvancedStakeRewardController` (1,748,708.47 ZKP) into the Polygon Vault.
4. Set the Merkle root on `VaultV0Frozen`, opening the claim window for the 1,235 eligible stakers.

After execution, every eligible address can call `VaultV0Frozen.claim(zkpAmount, nftCount, claimNft, proof)` once. The proof JSON is pinned at IPFS CID `QmXjozQCksvwrPHGivRJqRDhmatJ8Gh3Fb33jYc7BkSSzN`.

## Execution layout — 7 logical actions, 8 Ethereum txs in the Safe batch

| #   | Chain    | Target                                           | Method                                               | Mode         | Mainnet Safe-batch entries |
| --- | -------- | ------------------------------------------------ | ---------------------------------------------------- | ------------ | -------------------------- |
| 1   | Ethereum | `VestingPools` (`0xb476…CF14B`)                  | `addVestingPools`                                    | direct       | 1                          |
| 2   | Ethereum | `VestingPools`                                   | `updatePoolTime`                                     | direct       | 1                          |
| 3   | Ethereum | `VestingPools`                                   | `releaseTo` (→ DAO)                                  | direct       | 1                          |
| 4   | Ethereum | `VestingPools`                                   | `releaseTo` (→ Base deployer)                        | direct       | 1                          |
| 5   | Ethereum | `ZKP` (`0x909E…fA173`)                           | `approve` (predicate, shortfall)                     | direct       | 1                          |
| 6   | Ethereum | `RootChainManager` (`0xA0c6…7C77`)               | `depositFor` (bridges shortfall to Vault on Polygon) | direct       | 1                          |
| 7   | Polygon  | `AdvancedStakeRewardController` (`0x8f15…14de3`) | `rescueErc20` (ZKP → Vault)                          | **bridge B** | 1 (FxRoot wrapper)         |
| 8   | Polygon  | `VaultV0Frozen` proxy (`0x5E7F…486c9`)           | `setRoot(<merkle root>)`                             | **bridge B** | 1 (FxRoot wrapper)         |

Total Ethereum txs in the Safe batch = **6 direct + 2 FxRoot wrappers = 8**.

## Per-action details

### Ethereum side (6 direct actions)

All executed as `msg.sender = DAO Multisig` (`0x505796f5…dfd77`). No bridge wrapping — each is a plain Safe Transaction Builder entry with `to = <target>`.

Raw `{to, value, data, method, params}` for each is in `contracts/PIP-38-ethereum-actions.json`.

1. **`addVestingPools([dao], [poolParams])`** — creates pool id **23** with total allocation `5_492_496_050_190 × 1e12` wei, wallet = DAO multisig. Pool params: `isPreMinted = false`, `isAdjustable = true`, `start = nowBase + 35 days`, `vestingDays = 1`, `sAllocation = sUnlocked = 5_492_496_050_190`. The 35-day buffer covers the Snapshot vote + execution latency.
2. **`updatePoolTime(23, nowBase - 2 days, 1)`** — moves the pool start into the past so the entire allocation is immediately releasable. Works because `_timeNow() > end = start + 1d` holds.
3. **`releaseTo(23, dao, 392_496_050_190_000_000_000_000)`** — releases 392,496.05019 ZKP to the DAO multisig.
4. **`releaseTo(23, baseDeployer, 5_100_000_000_000_000_000_000_000)`** — releases 5,100,000 ZKP to `0xeE3c1d…3742`. After this, `pool.vested == pool.sAllocation * SCALE`.
5. **`ZKP.approve(0x40ec5B…BbbDf, 392_496_050_190_000_000_000_000)`** — approves the Polygon PoS ERC-20 predicate.
6. **`RootChainManager.depositFor(0x5E7Fda6d…486c9, ZKP, abi.encode(uint256(392…)))`** — bridges 392k ZKP straight to the Vault proxy on Polygon. Standard Polygon PoS checkpoint timing applies (~30 min); does NOT block any other on-chain step.

### Polygon side (2 bridge-Mode-B actions)

Each is wrapped per GOVERNANCE.md Mode B. The inner call executes on Polygon as `msg.sender = polygonMultisig (0x208Fb…)` after MaticBridgeModule.execTransactionFromModule.

For each, the generation agent builds:

```
bridgePayload = abi.encode(<inner.to>, 0, <inner.data>, 0, maticBridgeModule.nonce + i)
ethereumTx    = FxRoot.sendMessageToChild(maticBridgeModule, bridgePayload)
```

Read `MaticBridgeModule.nonce()` live at generation time. Bridge nonces must be consecutive in execution order: `n` for action 7, `n + 1` for action 8.

Raw `{to, value, data, method, params}` for each inner call is in `contracts/PIP-38-polygon-actions.json`.

7. **`AdvancedStakeRewardController.rescueErc20(ZKP, vault, balance)`** — drains the controller's full ZKP balance (≈ 1,748,708.47 ZKP) into the Polygon Vault. `rewardParams.endTime` is already past (May 2024), so the rescue path is unlocked — no preparation tx needed.
8. **`VaultV0Frozen.setRoot(0x6abb6e25…af5e)`** — opens the claim window. One-shot setter; also starts the 1-year clock for owner sweep functions.

After execution, eligible stakers can call `VaultV0Frozen.claim(...)`. By the time they actually claim, the bridged 392k will have landed in the Vault (≈ 30 min after the L1 checkpoint).

## Key addresses (verify on-chain before signing)

| Symbol                                          | Address                                      | Chain    |
| ----------------------------------------------- | -------------------------------------------- | -------- |
| DAO Multisig                                    | `0x505796f5bc290269d2522cf19135ad7aa60dfd77` | Ethereum |
| FxRoot                                          | `0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2` | Ethereum |
| VestingPools                                    | `0xb476104aa9D1f30180a01987FB09b1e96dDCF14B` | Ethereum |
| ZKP token                                       | `0x909E34d3f6124C324ac83DccA84b74398a6fa173` | Ethereum |
| ERC-20 predicate                                | `0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf` | Ethereum |
| RootChainManager                                | `0xA0c68C638235ee32657e8f720a23ceC1bFc77C77` | Ethereum |
| Base deployer wallet                            | `0xeE3c1dDBCB795ff2fA12330149DEA0369bF03742` | Ethereum |
| Polygon Multisig (= MaticBridgeModule executor) | `0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0` | Polygon  |
| MaticBridgeModule                               | `0x4A4FC40d2475f493EcA3Ec436b924237AA1b0a76` | Polygon  |
| AdvancedStakeRewardController                   | `0x8f15a43961c27C74CB4F55234A78802401614de3` | Polygon  |
| VaultV0Frozen proxy                             | `0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9` | Polygon  |
| VaultV0Frozen impl (already live)               | `0x31f63DD9Dd1ba6A4b265A31686139Af7F1cdf923` | Polygon  |
| ZKP token (PZKP)                                | `0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC` | Polygon  |

## Constants the agent must use verbatim

- Merkle root for `setRoot`: `0x6abb6e25bebc3edb33165f95bae9393996be5b3e83f88c1b4c626b471badaf5e`
- Shortfall bridged: `392_496_050_190_000_000_000_000` wei (392,496.05019 ZKP)
- Base allocation: `5_100_000_000_000_000_000_000_000` wei (5,100,000 ZKP)
- Pool sAllocation: `5_492_496_050_190` (uint48; × `1e12` → wei)
- Pool wallet: DAO Multisig (`0x505796f5…dfd77`)
- New pool id: 23 (hardcoded; sanity-check `getPool(23)` reverts on the live chain right before generation — if any new pool was added in the meantime, bump this)

## Pre-generation checklist

Run the spec files first; they validate everything against a fresh fork of the latest block:

```bash
# Ethereum side (forked Ethereum)
HARDHAT_FORKING_URL=$ETHEREUM_RPC HARDHAT_FORKING_ENABLED=1 \
  HARDHAT_FORKING_BLOCK=<latest> \
  npx hardhat test test/protocol/PIP38EthereumActions.forked.spec.ts
# → produces PIP-38-ethereum-actions.json (actions 1..6, direct)

# Polygon side (forked Polygon)
HARDHAT_FORKING_URL=$POLYGON_RPC HARDHAT_FORKING_ENABLED=1 \
  HARDHAT_CHAIN_ID=137 HARDHAT_FORKING_BLOCK=<latest> \
  npx hardhat test test/protocol/PIP38PolygonActions.forked.spec.ts
# → produces PIP-38-polygon-actions.json (actions 7..8, inner calls for bridge)
```

Both specs must pass and produce non-empty `actions` arrays before the agent starts wrapping.

## Wrapping rules (per GOVERNANCE.md)

- **Direct actions (1..6)** → Safe Transaction Builder entry: `{ to: <action.to>, value: "0.0", data: <action.data>, operation: "0", method: <action.method>, params: <action.params> }`.
- **Bridge actions (7..8)** → Safe Transaction Builder entry: `{ to: FxRoot, value: "0.0", data: encode("sendMessageToChild", [MaticBridgeModule, bridgePayload]), operation: "0", method: "sendMessageToChild(address,bytes)", params: [MaticBridgeModule, bridgePayload] }`. `bridgePayload` = `abi.encode(action.to, 0, action.data, 0, bridgeNonce)`. Use consecutive bridge nonces in execution order starting from the live `MaticBridgeModule.nonce()`.

Final batch order on Ethereum: **1, 2, 3, 4, 5, 6, 7-wrapped, 8-wrapped**.

The final deliverable is `proposal_txs_data.txt` per `GOVERNANCE.md §3.5` — the human-readable section's `Data:` hex strings must match the JSON batch's `data` fields byte-for-byte. Don't ship without that cross-check.
