# Panther Protocol — Cross-Chain Governance Handoff

This document is a self-contained operational reference for preparing, simulating, and shipping governance proposals that affect Panther Protocol contracts on Polygon, executed by the Ethereum DAO Multisig via the Polygon PoS bridge.

If you are a new developer or an AI agent picking this up cold, you should be able to prepare a new proposal end-to-end with **only this document** plus the proposal goal. All addresses, scripts, code paths, commands, and pitfalls below are taken from the repository at `core/contracts/` and verified against on-chain state.

---

## 1. High-Level Governance Architecture

### 1.1 Governance model

Panther Protocol is governed by two cooperating Gnosis Safes — one on Ethereum (where Snapshot voting and proposal execution happens) and one on Polygon (the on-chain executor of cross-chain actions).

- **Snapshot vote** is held off-chain. Approval gives the Ethereum DAO Multisig signers authority to execute the proposal calldata.
- **Ethereum DAO Multisig** signs and executes the proposal on Ethereum. Each transaction in the proposal is a call to `FxRoot` that emits a state-sync event.
- **Polygon PoS bridge** (FxPortal) relays the message from Ethereum to Polygon asynchronously. Heimdall validators sign the state sync; Polygon validators include it in a checkpoint.
- **MaticBridgeModule** on Polygon receives the bridged message via `FxChild`. It is a Safe **module** enabled on the Polygon Multisig (`0x208Fb…`). It executes the message body **as 0x208Fb** by calling `execTransactionFromModule` on 0x208Fb.
- **0x208Fb (Polygon Multisig)** is therefore the effective executor of every cross-chain action. It may call any contract on Polygon that recognizes it as an admin/owner. For actions on `ownerSafeDao` (which is a separate Safe), 0x208Fb uses Safe's `approveHash` + `execTransaction` pattern (described below).

### 1.2 Trust assumptions

- Ethereum DAO Multisig (`0x505796f5…`) is correctly configured (threshold 2-of-5) and its signers are honest.
- Polygon Multisig (`0x208Fb…`) is correctly configured (threshold 2-of-4); MaticBridgeModule is enabled as a module on it.
- The FxPortal bridge (FxRoot / FxChild / StateSender) is operational and not censored.
- MaticBridgeModule enforces `rootMessageSender == 0x505796f5…` (the Ethereum DAO Multisig) before executing any payload. Only messages originating from that sender are accepted.
- MaticBridgeModule maintains a strictly-increasing internal `nonce()` to prevent replay and enforce ordering.

### 1.3 Three execution modes

Panther governance has THREE distinct execution patterns. Always identify which one a new proposal needs before encoding anything.

| Mode                          | When to use                                                                                                                                         | Who signs                                | Where it runs                                        | Calldata shape                                                                   |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------- |
| **A. Polygon-direct**         | Target's owner/admin is a Polygon Safe whose signers can sign directly on Polygon (no Ethereum vote required)                                       | The Polygon Safe owners (e.g. `0x208Fb`) | Polygon                                              | A single Safe tx: `{to, data, value, operation}`                                 |
| **B. Cross-chain single-hop** | Target on Polygon is owned/admin'd by `0x208Fb` directly (e.g. proxies whose `owner` is `0x208Fb`)                                                  | Ethereum DAO Multisig                    | Ethereum → bridge → Polygon                          | One `FxRoot.sendMessageToChild(MaticBridgeModule, payload)` per logical action   |
| **C. Cross-chain double-hop** | Target on Polygon is `ownerSafeDao` (or any Safe whose owner is `0x208Fb`), so msg.sender authority is not enough — a Safe signature path is needed | Ethereum DAO Multisig                    | Ethereum → bridge → Polygon → 0x208Fb → ownerSafeDao | **Two** bridge messages per logical action: `approveHash` then `execTransaction` |

PIP-32 (already shipped) is a Mode C example. The earlier `03-upgrade-fee-master-proxy.ts` is a Mode A example. The `06-upgrade-vault-v1-proxy.ts` is a Mode B example.

### 1.4 End-to-end flow (Mode B and C)

```
[Snapshot vote passes]
        │
        ▼
[Ethereum DAO Multisig signs N FxRoot calls]   ← N = 1 per action (Mode B) or 2 per action (Mode C)
        │
        ▼
FxRoot.sendMessageToChild(MaticBridgeModule, encodedPayload)
        │
        ▼ (StateSender emits StateSynced; checkpoint to Polygon ≈ 22 min)
        │
[FxChild on Polygon] ── onStateReceive(stateId, data) ──▶
        │
        ▼
MaticBridgeModule.processMessageFromRoot(stateId, rootMessageSender, data)
   • require(msg.sender == FxChild)
   • require(rootMessageSender == 0x505796f5…)
   • abi.decode(data, (address target, uint256 value, bytes inner, uint8 op, uint256 expectedNonce))
   • require(expectedNonce == module.nonce); module.nonce++;
        │
        ▼
0x208Fb.execTransactionFromModule(target, value, inner, op)   ← msg.sender becomes 0x208Fb at `target`
        │
        ├── Mode B: target executes inner directly (e.g. proxy.upgradeTo)
        │
        └── Mode C: target is ownerSafeDao
              ├── Msg #1: 0x208Fb.approveHash(safeTxHash)         on ownerSafeDao
              └── Msg #2: 0x208Fb.execTransaction(... v=1 sig...) on ownerSafeDao
```

---

## 2. Contract & Address Registry

All values below are mainnet. Test/Amoy values live in `contracts/deploy/03-config/utils.ts`.

### 2.1 Cross-chain bridge (fixed, never changes)

| Symbol                                                  | Address                                      | Chain    | Source of truth                                                         |
| ------------------------------------------------------- | -------------------------------------------- | -------- | ----------------------------------------------------------------------- |
| `daoMultisig` (Ethereum DAO Safe)                       | `0x505796f5bc290269d2522cf19135ad7aa60dfd77` | Ethereum | `BRIDGE_ADDRESSES.daoMultisig` in `contracts/deploy/03-config/utils.ts` |
| `fxRoot`                                                | `0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2` | Ethereum | `BRIDGE_ADDRESSES.fxRoot`                                               |
| `stateSender` (internal, used by FxRoot)                | `0x28e4f3a7f651294b9564800b2d01f35189a5bfbe` | Ethereum | Read from FxRoot storage slot 0                                         |
| `fxChild`                                               | `0x8397259c983751daf40400790063935a11afa28a` | Polygon  | `BRIDGE_ADDRESSES.fxChild`                                              |
| `maticBridgeModule`                                     | `0x4A4FC40d2475f493EcA3Ec436b924237AA1b0a76` | Polygon  | `BRIDGE_ADDRESSES.maticBridgeModule`                                    |
| `polygonMultisig` (= `0x208Fb` = "newSigner" in PIP-32) | `0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0` | Polygon  | `BRIDGE_ADDRESSES.polygonMultisig`                                      |

### 2.2 Protocol governance targets

| Symbol         | Address                                      | Chain   | Notes                  |
| -------------- | -------------------------------------------- | ------- | ---------------------- |
| `ownerSafeDao` | `0x026a024b13B4Ca23897ad578264C0ec543f904b9` | Polygon | A Safe. Mode C target. |

Proxy/implementation addresses for live protocol contracts (FeeMaster, Vault, Paymaster, etc.) are managed by `hardhat-deploy` and live under `contracts/deployments/polygon/` and `contracts/deployments/mainnet/`. Always read them with `await deployments.get('<Name>')` rather than hardcoding.

### 2.3 Signer composition (verified on-chain as of latest read)

`0x505796f5…` (Ethereum DAO Multisig) — threshold **2-of-5**:

- `0xef5795c6a59549100afbfdc209be63ed85e6a402`
- `0xe661154ae8a02b6bbd3f7f7d55ced0d86d99fda1`
- `0x09e43cf49d8bcee4256bee50a9b1652556a597cb`
- `0x1b18fad5d149addd747aa523e0ab188cb7b80765`
- `0x109484349cb5f1128030d3a5db54462ba9cd45a7`

`0x208Fb…` (Polygon Multisig) — threshold **2-of-4**:

- `0xe661154ae8a02b6bbd3f7f7d55ced0d86d99fda1`
- `0x09e43cf49d8bcee4256bee50a9b1652556a597cb`
- `0x1b18fad5d149addd747aa523e0ab188cb7b80765`
- `0x109484349cb5f1128030d3a5db54462ba9cd45a7`

`ownerSafeDao` (post PIP-32 will be) — threshold **1**, single owner `0x208Fb…`.

> **Always re-read live state before submitting a proposal.** Signers and thresholds can change. Use the read snippets in Section 5.

### 2.4 Ownership / admin relationships

```
Ethereum DAO Multisig (0x505796f5…, 2-of-5)
   │  (only authorized rootMessageSender on MaticBridgeModule)
   ▼
MaticBridgeModule (0x4A4FC4…)
   │  (enabled as Safe Module on 0x208Fb)
   ▼
Polygon Multisig 0x208Fb (2-of-4)
   │
   ├── direct admin of many Polygon proxies (Mode B targets)
   │
   └── owner of ownerSafeDao (Mode C target)
         │
         └── owns/controls protocol-level Polygon contracts and roles
```

---

## 3. Proposal Lifecycle

### 3.1 Phases

1. **Define goal.** Translate the human-language ask into one or more on-chain calls. Identify the target contract, function, args, and which execution mode (A/B/C) applies.
2. **Write the proposal script.** Add a TypeScript file under `contracts/deploy/03-config/<version>/` (use the pattern in Section 6.3) that:
   - reads the target contract addresses via `hardhat-deploy`
   - encodes the action (`populateTransaction.<method>(args)`)
   - wraps it correctly for the chosen execution mode
   - calls `saveSafeTransaction(...)` to emit a JSON file under `contracts/deployments/safe-transactions/`
3. **Simulate on a fork.** For cross-chain proposals, run the dedicated Hardhat tasks against a freshly-forked Polygon (and Ethereum) at the latest block. See Section 6 for commands.
4. **Generate calldata.** Produce a Snapshot-ready file containing:
   - the per-tx `to` (always `FxRoot` for cross-chain proposals)
   - the per-tx `data`
   - the Gnosis Safe Transaction Builder JSON batch
5. **Submit proposal to Snapshot.** Paste the human-readable summary and the JSON batch. Vote runs off-chain.
6. **Execute.** After vote passes, an Ethereum DAO signer loads the batch into Gnosis Safe Transaction Builder and the 2-of-5 signs and executes. FxRoot emits `StateSynced` for each tx.
7. **Wait for bridge.** Polygon validators include the state sync in a checkpoint (typically ~22 minutes; sometimes longer under congestion). FxChild calls MaticBridgeModule, which executes the action.
8. **Verify.** Inspect the resulting state on Polygon (owner lists, proxy implementation slots, etc.).

### 3.2 What can fail at each phase

| Phase               | Failure mode                                                                                       | Detection                                             |
| ------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Define goal         | Wrong execution mode chosen (e.g. Mode B used for a Safe target — call fails because no signature) | Caught by fork simulation                             |
| Write script        | Hardcoded address that has moved / wrong nonce / wrong encoding                                    | Fork simulation reverts                               |
| Simulate            | Stale fork block hides real nonce drift                                                            | Always fork at `latest` block, never a cached one     |
| Generate calldata   | Safe nonce changes after generation                                                                | Re-generate immediately before signing                |
| Submit Snapshot     | Wrong target / wrong batch order                                                                   | Manual cross-check against the human-readable section |
| Execute on Ethereum | Sig threshold not met, hooks reverting                                                             | Tx revert on Ethereum                                 |
| Bridge              | Bridge censored/slow; checkpoint delayed                                                           | Watch StateSynced events + Polygon explorer           |
| Polygon execution   | Module nonce drift; Safe nonce drift; wrong prevOwner in linked list                               | Polygon tx revert                                     |
| Verify              | Did not check final state                                                                          | Always inspect `getOwners()`, proxy slots, etc.       |

---

## 3.5 Required Deliverable: the `proposal_txs_data.txt` File

The final artifact a future agent must produce for any cross-chain proposal is a single human + machine readable file named (or equivalent to) `proposal_txs_data.txt`. This is the file that gets pasted into the Snapshot proposal description and whose JSON batch is loaded into Gnosis Safe Transaction Builder for signing.

### 3.5.1 Hard requirements before producing this file

1. The agent MUST have run a successful **Polygon fork simulation at the latest Polygon block** (read `eth_blockNumber` live, pass it to `HARDHAT_FORKING_BLOCK`). The simulation must:
   - read live `ownerSafeDao.nonce`, `ownerSafeDao.threshold`, `ownerSafeDao.getOwners()`, `MaticBridgeModule.nonce()`,
   - execute every bridge payload in order via the impersonated `fxChild`,
   - assert the post-state matches the proposal's intent.
2. The agent MUST have run a successful **Ethereum fork simulation at the latest Ethereum block**. The simulation must:
   - impersonate the Ethereum DAO Multisig (`0x505796f5…`),
   - submit each `FxRoot.sendMessageToChild` transaction,
   - assert each tx succeeded and emitted a `StateSynced(uint256,address,bytes)` event.
3. The agent MUST verify byte-for-byte that the "Tx #N → Data:" hex strings in the human-readable section equal the `"data"` strings in the JSON batch at the bottom. They are the same calldata duplicated in two presentations and must never diverge.
4. The agent MUST NOT submit, ask the user to submit, or paste the file anywhere until the user has explicitly confirmed they reviewed every transaction.

If any of (1), (2), or (3) fail, the file is invalid. Do not deliver it.

### 3.5.2 File structure (template)

The file is plain text. Replace `<…>` placeholders with proposal-specific values. The JSON batch at the bottom is the only machine-parsed section — its format must match exactly what Gnosis Safe Transaction Builder expects.

```
** <PROPOSAL_ID>: <ONE_LINE_GOAL> **

** Addresses **

Panther contracts on Ethereum:
    - DAO_Multisig@eth: 0x505796f5bc290269d2522cf19135ad7aa60dfd77
    - FxRoot@eth: 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2

Panther contracts on Polygon:
    - ownerSafeDao@matic: 0x026a024b13B4Ca23897ad578264C0ec543f904b9
    - newSigner (DAO Safe)@matic: 0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0
    - MaticBridgeModule@matic: 0x4A4FC40d2475f493EcA3Ec436b924237AA1b0a76
    - <ANY_OTHER_TARGET_CONTRACTS_TOUCHED_BY_THIS_PROPOSAL>

** Transactions for the Snapshot **

Transactions Overview
   # <ONE_PARAGRAPH_EXPLAINING_WHAT_THIS_PROPOSAL_DOES_AND_WHY>
    1. FxRoot@eth::sendMessageToChild(MaticBridgeModule, encodedData) // <SHORT_DESCRIPTION_OF_TX_1>
    2. FxRoot@eth::sendMessageToChild(MaticBridgeModule, encodedData) // <SHORT_DESCRIPTION_OF_TX_2>
    <... one line per Ethereum transaction ...>

** Batch #1 **
========

    Tx #1: <SHORT_DESCRIPTION_OF_TX_1>
        To:
            0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2 // FxRoot@eth
        Value:
            0
        Data:
            0xb47204770000000000000000000000004a4fc40d2475f493eca3ec436b924237aa1b0a76…

    Tx #2: <SHORT_DESCRIPTION_OF_TX_2>
        To:
            0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2 // FxRoot@eth
        Value:
            0
        Data:
            0xb47204770000000000000000000000004a4fc40d2475f493eca3ec436b924237aa1b0a76…

    <... one Tx #N block per Ethereum transaction ...>


    Batch Transaction Hash:

    [
        {
            "to": "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
            "operation": "0",
            "value": "0.0",
            "data": "0xb4720477…",
            "method": "sendMessageToChild(address,bytes)",
            "params": [
                "0x4A4FC40d2475f493EcA3Ec436b924237AA1b0a76",
                "0x<bridge_payload_bytes>"
            ]
        },
        {
            "to": "0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2",
            "operation": "0",
            "value": "0.0",
            "data": "0xb4720477…",
            "method": "sendMessageToChild(address,bytes)",
            "params": [
                "0x4A4FC40d2475f493EcA3Ec436b924237AA1b0a76",
                "0x<bridge_payload_bytes>"
            ]
        }
    ]
```

Notes on the format:

- The address block lists every contract relevant to humans reading the proposal. Always include the bridge-side addresses (`DAO_Multisig@eth`, `FxRoot@eth`, `ownerSafeDao@matic`, `newSigner@matic`, `MaticBridgeModule@matic`). Add the actual target Polygon contract(s) if they are not already in that list.
- Every `To:` is `FxRoot@eth` (`0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2`). The proposal never targets Polygon contracts directly because it is executed on Ethereum.
- Every `Value:` is `0`. The bridge does not require ETH.
- Every `operation` in the JSON batch is `"0"` (CALL).
- Every `value` in the JSON batch is `"0.0"` (Tx Builder writes it as a decimal string).
- Every entry includes `method` (`"sendMessageToChild(address,bytes)"`) and `params` (`[maticBridgeModule, bridgePayload]`). `params[1]` is the ABI-encoded `(address target, uint256 value, bytes inner, uint8 op, uint256 expectedNonce)` bridge payload — same bytes the MaticBridgeModule will decode on Polygon. Tx Builder uses `method`+`params` to render human-readable args alongside the raw `data` and verifies they match.
- **No `// …` comments inside the JSON arrays.** Strict JSON parsers (including some Gnosis Safe Tx Builder versions and any downstream tooling that feeds the batch through `JSON.parse` / `json.loads`) reject `// label` annotations and will refuse to import the batch. Inline `// FxRoot@eth` / `// VestingPools@eth` labels are encouraged in the human-readable `Tx #N → To:` blocks above the JSON arrays — but the arrays themselves must be valid RFC-8259 JSON. The generator pass-through should write `"to": "0x…",` with no trailing comment.
- The number of Ethereum transactions equals: **1 × (Mode B logical actions) + 2 × (Mode C logical actions)**. For PIP-32 (Mode C with two removals): 2 × 2 = 4 transactions.

### 3.5.3 Generation pipeline

For Mode C proposals, the existing pair of Hardhat tasks already produces a valid `tx-data.txt`. Use them as the canonical pipeline:

```
contracts/tasks/test-proposal.ts         (pip-32-bridge + pip-32-ethereum)
   │
   ├─ pip-32-bridge      → bridge-messages.json     (intermediate)
   └─ pip-32-ethereum    → ethereum-transactions.json + tx-data.txt   (deliverable)

contracts/tasks/test-ethereum-txs.ts     (pip-32-test-ethereum)
   └─ verifies tx-data.txt's transactions on a forked Ethereum at latest block
```

For a new proposal:

1. Either reuse `test-proposal.ts` (recommended for Mode C, update the `removeSignerViaBridge` body to encode your new action) or write a parallel pair of tasks (`<proposal-id>-bridge`, `<proposal-id>-ethereum`, `<proposal-id>-test-ethereum`) that follow the same input → intermediate → deliverable layout.
2. The Polygon-side task MUST read `eth_blockNumber` live (or accept it through `HARDHAT_FORKING_BLOCK`) and assert preconditions before generating.
3. The Ethereum-side task MUST regenerate the file from `bridge-messages.json` rather than re-encoding from scratch, so the two stages cannot drift apart.
4. After all three tasks pass, the agent runs a final byte-for-byte equality check between the "Data:" section and the JSON batch and only then presents the file to the user.

### 3.5.4 Required commands (exact)

The agent must run these commands in order. The two `LATEST_*` variables are computed live; never reuse a stale value from a prior run.

```bash
# Step 1 — Polygon fork simulation at latest block
LATEST_POLYGON=$(curl -s -X POST "$POLYGON_RPC" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
  | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))")

HARDHAT_FORKING_URL="$POLYGON_RPC" \
HARDHAT_FORKING_ENABLED=true \
HARDHAT_CHAIN_ID=137 \
HARDHAT_FORKING_BLOCK=$LATEST_POLYGON \
npx hardhat <proposal-id>-bridge

# Step 2 — Generate the deliverable (no fork)
npx hardhat <proposal-id>-ethereum

# Step 3 — Ethereum fork verification at latest block
LATEST_ETH=$(curl -s -X POST "$ETHEREUM_RPC" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
  | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))")

HARDHAT_FORKING_URL="$ETHEREUM_RPC" \
HARDHAT_FORKING_ENABLED=true \
HARDHAT_FORKING_BLOCK=$LATEST_ETH \
npx hardhat <proposal-id>-test-ethereum

# Step 4 — byte-for-byte cross-check AND strict-JSON validity check
python3 - <<'PY'
import re, json
with open('tx-data.txt') as f:
    content = f.read()
section = [l.strip() for l in content.split('\n') if l.strip().startswith('0xb4720477')]
batch   = re.findall(r'"data":\s*"(0xb4720477[a-f0-9]+)"', content)
assert section == batch, "section/batch mismatch — DO NOT SUBMIT"
print(f"OK: {len(section)} transactions, section ↔ batch match")

# Strict-JSON guard: each JSON array under a 'Batch Transaction Hash:' or
# 'Batch #N — JSON …' header must parse cleanly. Catches `// comment` leaks.
arrays = re.findall(r'(?:Batch Transaction Hash:|Batch #\d+ — JSON[^\n]*\*\*).*?\n\s*(\[.*?\n    \])', content, re.S)
for i, txt in enumerate(arrays, 1):
    json.loads(txt)  # raises on // comments or any other JSON violation
print(f"OK: all {len(arrays)} JSON batches parse with json.loads (no // comments)")
PY
```

If any step fails, the deliverable is invalid. Re-investigate before retrying.

---

## 4. Worked Example: PIP-32

PIP-32 removes the two legacy signers from `ownerSafeDao`, leaving only `0x208Fb…` as the sole owner with threshold 1.

### 4.1 Pre-state (verified on Polygon)

- `ownerSafeDao.threshold = 1`
- `ownerSafeDao.getOwners() = [0x208Fb…, 0xFee6D2Cb…, 0xb83A3094…]`
- `ownerSafeDao.nonce = 94` (at the time of generation; will move)
- `maticBridgeModule.nonce = 46`
- Owner linked list: `SENTINEL → 0x208Fb → 0xFee6D2Cb → 0xb83A3094 → SENTINEL`

### 4.2 Logical actions

1. Remove `0xFee6D2Cb…` with `prevOwner = 0x208Fb`. New threshold: 1.
2. Remove `0xb83A3094…` with `prevOwner = 0x208Fb`. New threshold: 1.

Each action needs **two** bridge messages because `ownerSafeDao` is a Safe (Mode C). Total: **4 FxRoot transactions**.

### 4.3 Encoding flow (per action)

For each signer-to-remove, compute the Safe transaction hash:

```
SafeTx = {
  to: ownerSafeDao,
  value: 0,
  data: encodeFunctionData('removeOwner', [prevOwner, ownerToRemove, newThreshold=1]),
  operation: 0,                  // CALL
  safeTxGas: 0, baseGas: 0, gasPrice: 0,
  gasToken: 0x0, refundReceiver: 0x0,
  nonce: <current ownerSafeDao nonce>
}
safeTxHash = EIP-712 hash with domain {verifyingContract: ownerSafeDao, chainId: 137}
```

**Bridge message 1 — approveHash:**

```
inner = ownerSafeDao.approveHash.encodeFunctionData([safeTxHash])
payload = abi.encode(
   address target = ownerSafeDao,
   uint256 value = 0,
   bytes   data  = inner,
   uint8   op    = 0,
   uint256 nonce = <maticBridgeModule.nonce>
)
ethereumTx = FxRoot.sendMessageToChild(MaticBridgeModule, payload)
```

**Bridge message 2 — execTransaction:**

```
sig = 0x000000000000000000000000<0x208Fb addr (no prefix)>
      0000000000000000000000000000000000000000000000000000000000000000
      01                                                           // v=1 -> pre-approved by msg.sender
inner = ownerSafeDao.execTransaction.encodeFunctionData([
            SafeTx.to, SafeTx.value, SafeTx.data, SafeTx.operation,
            SafeTx.safeTxGas, SafeTx.baseGas, SafeTx.gasPrice,
            SafeTx.gasToken, SafeTx.refundReceiver,
            sig
        ])
payload = abi.encode(ownerSafeDao, 0, inner, 0, <maticBridgeModule.nonce + 1>)
ethereumTx = FxRoot.sendMessageToChild(MaticBridgeModule, payload)
```

The `v=1` signature format with the signer address in the `r` field instructs Safe to look up `approvedHashes[r][safeTxHash]`. Because message 1 already wrote that entry as 0x208Fb, message 2 passes the threshold-1 check and the `removeOwner` call executes.

### 4.4 Scripts used

- `contracts/tasks/test-proposal.ts` — defines two Hardhat tasks:
  - `pip-32-bridge`: Polygon fork simulation that reads live nonces, builds bridge messages, executes them through MaticBridgeModule, and writes `bridge-messages.json`.
  - `pip-32-ethereum`: wraps each bridge message in `FxRoot.sendMessageToChild` and writes `ethereum-transactions.json` and `tx-data.txt` (human-readable + JSON batch).
- `contracts/tasks/test-ethereum-txs.ts` — `pip-32-test-ethereum`: replays the 4 Ethereum transactions on a forked Ethereum mainnet, asserts they succeed, and verifies a `StateSynced` event is emitted for each.

### 4.5 Commands

From `contracts/`:

```bash
# Step 1 — Polygon fork simulation (always re-read latest live block!)
LATEST_POLYGON=$(curl -s -X POST "$POLYGON_RPC" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
  | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))")
HARDHAT_FORKING_URL="$POLYGON_RPC" \
HARDHAT_FORKING_ENABLED=true \
HARDHAT_CHAIN_ID=137 \
HARDHAT_FORKING_BLOCK=$LATEST_POLYGON \
npx hardhat pip-32-bridge

# Step 2 — Generate Ethereum calldata (no fork needed)
npx hardhat pip-32-ethereum

# Step 3 — Ethereum fork verification
LATEST_ETH=$(curl -s -X POST "$ETHEREUM_RPC" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
  | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))")
HARDHAT_FORKING_URL="$ETHEREUM_RPC" \
HARDHAT_FORKING_ENABLED=true \
HARDHAT_FORKING_BLOCK=$LATEST_ETH \
npx hardhat pip-32-test-ethereum
```

`HARDHAT_FORKING_BLOCK` for Ethereum is **required** under Node.js v25 due to a Hardhat detect-network bug at "latest".

### 4.6 Intermediate outputs (PIP-32 reference values)

At Safe nonce 94 / bridge nonce 46, the test output produced:

| Element                                                    | Value                                                                |
| ---------------------------------------------------------- | -------------------------------------------------------------------- |
| Safe txHash for signer1 removal                            | `0x4bb42bcb64c307668f6308cbddc22a30479e62fb79395cd6a3bde192fbf27fbf` |
| Safe txHash for signer2 removal                            | `0xdce0783e2a61918bd582092c5d46022efb3ecf05c6b3edcf800ade2bbc915a6c` |
| Bridge nonces used (in order)                              | 46, 47, 48, 49                                                       |
| All 4 `FxRoot.sendMessageToChild` succeed on Ethereum fork | ✅                                                                   |
| `StateSynced` event emitted for each                       | ✅                                                                   |
| Final Polygon owners after simulation                      | `[0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0]`                       |

Final files used in the proposal:

- `contracts/ethereum-transactions.json` — array of 4 `{order, message, ownerToRemove, nonce, to, value, data}` entries.
- `contracts/tx-data.txt` — human-readable layout per tx + Gnosis Safe Transaction Builder JSON batch at the bottom.

---

## 5. Code Examples — Read & Verify Snippets

The most important habit: **read live state before generating, and right before submission**.

### 5.1 Read Safe nonce + threshold + owners (Polygon)

```bash
# Safe nonce (selector 0xaffed0e0)
curl -s -X POST "$POLYGON_RPC" -H "Content-Type: application/json" -d '{
  "jsonrpc":"2.0","id":1,"method":"eth_call",
  "params":[{"to":"0x026a024b13B4Ca23897ad578264C0ec543f904b9","data":"0xaffed0e0"},"latest"]
}'

# Threshold (selector 0xe75235b8)
curl -s -X POST "$POLYGON_RPC" -H "Content-Type: application/json" -d '{
  "jsonrpc":"2.0","id":1,"method":"eth_call",
  "params":[{"to":"0x026a024b13B4Ca23897ad578264C0ec543f904b9","data":"0xe75235b8"},"latest"]
}'

# Owners (selector 0xa0e67e2b)
curl -s -X POST "$POLYGON_RPC" -H "Content-Type: application/json" -d '{
  "jsonrpc":"2.0","id":1,"method":"eth_call",
  "params":[{"to":"0x026a024b13B4Ca23897ad578264C0ec543f904b9","data":"0xa0e67e2b"},"latest"]
}'
```

### 5.2 Read MaticBridgeModule nonce

```bash
curl -s -X POST "$POLYGON_RPC" -H "Content-Type: application/json" -d '{
  "jsonrpc":"2.0","id":1,"method":"eth_call",
  "params":[{"to":"0x4A4FC40d2475f493EcA3Ec436b924237AA1b0a76","data":"0xaffed0e0"},"latest"]
}'
```

### 5.3 Verify MaticBridgeModule is enabled on 0x208Fb

```bash
# isModuleEnabled(0x4A4FC40d…) on 0x208Fb
curl -s -X POST "$POLYGON_RPC" -H "Content-Type: application/json" -d '{
  "jsonrpc":"2.0","id":1,"method":"eth_call",
  "params":[{"to":"0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0",
            "data":"0x2d9ad53d0000000000000000000000004a4fc40d2475f493eca3ec436b924237aa1b0a76"},
           "latest"]
}'
```

Expected result: `0x…01`.

### 5.4 Encode a Safe tx hash in TypeScript

```ts
import {ethers} from 'ethers';

const SAFE_TX_TYPEHASH = [
  {type: 'address', name: 'to'},
  {type: 'uint256', name: 'value'},
  {type: 'bytes', name: 'data'},
  {type: 'uint8', name: 'operation'},
  {type: 'uint256', name: 'safeTxGas'},
  {type: 'uint256', name: 'baseGas'},
  {type: 'uint256', name: 'gasPrice'},
  {type: 'address', name: 'gasToken'},
  {type: 'address', name: 'refundReceiver'},
  {type: 'uint256', name: 'nonce'},
];

const safeTxHash = ethers.utils._TypedDataEncoder.hash(
  {verifyingContract: ownerSafeDao, chainId: 137},
  {SafeTx: SAFE_TX_TYPEHASH},
  safeTx,
);
```

### 5.5 Build a v=1 pre-approval signature

```ts
function buildApprovalSignature(signerAddr: string): string {
  const a = signerAddr.slice(2).toLowerCase();
  return (
    '0x' +
    '000000000000000000000000' +
    a +
    '0000000000000000000000000000000000000000000000000000000000000000' +
    '01'
  );
}
```

### 5.6 Wrap an inner call in a bridge payload + FxRoot calldata

```ts
const payload = ethers.utils.defaultAbiCoder.encode(
  ['address', 'uint256', 'bytes', 'uint8', 'uint256'],
  [target, 0, innerCalldata, 0, expectedBridgeNonce],
);
const fxRoot = await ethers.getContractAt(fxRootAbi, BRIDGE_ADDRESSES.fxRoot);
const ethereumCalldata = (
  await fxRoot.populateTransaction.sendMessageToChild(
    BRIDGE_ADDRESSES.maticBridgeModule,
    payload,
  )
).data!;
```

### 5.7 Inspect FxRoot calldata after generation

To decode an Ethereum tx in `ethereum-transactions.json`:

1. First 4 bytes are `0xb4720477` — `sendMessageToChild(address,bytes)`.
2. Decode the outer args. The bytes arg is the bridge payload.
3. Decode the payload with `(address, uint256, bytes, uint8, uint256)`. The bridge nonce is the last `uint256`.
4. The inner `bytes` field is the call MaticBridgeModule will make through 0x208Fb. Its first 4 bytes tell you what it is:
   - `0xd4d9bdcd` — `approveHash(bytes32)` on a Safe.
   - `0x6a761202` — `execTransaction(...)` on a Safe.
   - `0x3659cfe6` — `upgradeTo(address)` on an EIP-173 proxy.
   - `0xf8dc5dd9` — `removeOwner(address,address,uint256)` on a Safe.

---

## 6. Repository & Tooling Guide

### 6.1 Directory layout

```
contracts/
├── contracts/                       Solidity sources
├── deploy/
│   ├── 03-config/                   Governance action scripts (config-time tasks)
│   │   ├── utils.ts                 BRIDGE_ADDRESSES, fxRootAbi, maticBridgeModuleAbi,
│   │   │                             createSafeTransaction, saveSafeTransaction
│   │   ├── v0/                      v0 protocol governance scripts
│   │   │                             Many use Mode A (direct Safe tx, no bridge)
│   │   └── v1/                      v1 protocol governance scripts
│   │       └── 06-upgrade-vault-v1-proxy.ts   Mode B example (single-hop cross-chain)
│   ├── ...
├── deployments/
│   ├── mainnet/                     Deployed addresses on Ethereum
│   ├── polygon/                     Deployed addresses on Polygon
│   └── safe-transactions/           Per-action JSON files written by saveSafeTransaction
├── tasks/
│   ├── test-proposal.ts             pip-32-bridge + pip-32-ethereum (Mode C scaffold)
│   ├── test-ethereum-txs.ts         pip-32-test-ethereum (Ethereum-side verification)
│   ├── README-pip-32.md             Operational guide for PIP-32
│   └── GOVERNANCE.md                THIS DOCUMENT
└── hardhat.config.ts                Networks and forking config
```

Output files (gitignored, regenerated each run):

- `contracts/bridge-messages.json`
- `contracts/ethereum-transactions.json`
- `contracts/tx-data.txt`

### 6.2 Hardhat-level configuration

`contracts/hardhat.config.ts`:

- `defaultNetwork: 'hardhat'`
- `networks.hardhat.forking` honors three env vars:
  - `HARDHAT_FORKING_URL` (required to fork)
  - `HARDHAT_FORKING_ENABLED` (must be set, any truthy string)
  - `HARDHAT_FORKING_BLOCK` (optional; required for Ethereum fork under Node.js v25)
- `networks.hardhat.chainId` is set from `HARDHAT_CHAIN_ID` (use `137` for Polygon fork; omit for Ethereum)

### 6.3 Pattern for a new governance script

For Mode B (cross-chain, single-hop) — modeled on `06-upgrade-vault-v1-proxy.ts`:

```ts
// contracts/deploy/03-config/v1/NN-<action-name>.ts
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {
    createSafeTransaction,
    saveSafeTransaction,
    BRIDGE_ADDRESSES,
    fxRootAbi,
    maticBridgeModuleAbi,
} from '../utils';

const func: DeployFunction = async function (hre) {
    const {ethers, deployments: {get}} = hre;

    // 1. Locate target on Polygon
    const {address: targetAddr} = await get('<TargetDeploymentName>');
    const target = await ethers.getContractAt('<TargetContract>', targetAddr);

    // 2. Encode the inner Polygon action
    const innerTx = await target.populateTransaction.<methodName>(<args>);

    // 3. Read CURRENT MaticBridgeModule nonce live (don't hardcode)
    const polygonProvider = new ethers.providers.JsonRpcProvider(process.env.POLYGON_RPC);
    const moduleContract = new ethers.Contract(
        BRIDGE_ADDRESSES.maticBridgeModule,
        maticBridgeModuleAbi,
        polygonProvider,
    );
    const bridgeNonce = (await moduleContract.nonce()).toNumber();

    // 4. Wrap in bridge payload
    const payload = ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint256', 'bytes', 'uint8', 'uint256'],
        [targetAddr, 0, innerTx.data!, 0, bridgeNonce],
    );

    // 5. Wrap in FxRoot.sendMessageToChild
    const fxRoot = await ethers.getContractAt(fxRootAbi, BRIDGE_ADDRESSES.fxRoot);
    const fxRootTx = await fxRoot.populateTransaction.sendMessageToChild(
        BRIDGE_ADDRESSES.maticBridgeModule,
        payload,
    );

    // 6. Save as a Safe transaction (to be loaded into Tx Builder)
    const safeTx = createSafeTransaction(BRIDGE_ADDRESSES.fxRoot, fxRootTx.data!);
    await saveSafeTransaction(hre, safeTx, __filename);
};

func.tags = ['config-v1', 'config-v1:<area>', 'config-v1:<action>'];
export default func;
```

For Mode C (cross-chain, double-hop on a Safe target), use `test-proposal.ts` as the template — it already implements `approveHash` + `execTransaction` with on-the-fly nonce reads and full fork simulation.

### 6.4 Required environment

- Node.js — repo runs on Hardhat which emits a warning on Node.js v25; v18 or v20 LTS is preferred but v25 works.
- `npm` deps installed via `npm install` (or `yarn`) in `contracts/`.
- Alchemy / Infura API key (set `ALCHEMY_API_KEY` or `INFURA_API_KEY`) — or pass a full URL via `HTTP_PROVIDER`. For fork tasks, set `HARDHAT_FORKING_URL` directly.
- Optional `.env` keys read by `hardhat.config.ts` and the tasks:
  - `HARDHAT_FORKING_URL`, `HARDHAT_FORKING_ENABLED`, `HARDHAT_FORKING_BLOCK`, `HARDHAT_CHAIN_ID`
  - `PRIVATE_KEY` or `MNEMONIC` (only needed for live broadcast — not needed for proposal prep)

### 6.5 Bash helpers

```bash
# Latest Polygon block
LATEST_POLYGON=$(curl -s -X POST "$POLYGON_RPC" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
  | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))")

# Latest Ethereum block
LATEST_ETH=$(curl -s -X POST "$ETHEREUM_RPC" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
  | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))")
```

---

## 7. Proposal Creation Playbook

Use this whenever you start a new proposal. Do not skip steps — the cost of skipping is operational risk.

### 7.1 Planning checklist

- [ ] Write the goal in one sentence. Identify the **target contract** on Polygon (or Ethereum), the **method** to call, and the **args**.
- [ ] Identify the **owner/admin** of the target. Use `cast call <target> "owner()" --rpc-url $POLYGON_RPC` or read the proxy admin slot for EIP-1967 proxies.
- [ ] Choose the execution mode:
  - Owner is a non-bridged Polygon Safe → Mode A.
  - Owner is `0x208Fb…` directly (e.g., proxy `owner = 0x208Fb`) → Mode B.
  - Owner is `ownerSafeDao` (`0x026a02…`) or another Safe whose owners include `0x208Fb` → Mode C.
- [ ] Confirm the function signature and args by reading the source code, not from external docs.

### 7.2 Pre-encoding checks (read live on-chain — do not trust memory)

- [ ] Read `0x208Fb` threshold and owners. Confirm 2-of-4 (or current).
- [ ] Read `0x505796f5` (Ethereum DAO Multisig) threshold and owners. Confirm 2-of-5 (or current).
- [ ] Read `MaticBridgeModule.nonce()` — that's the **starting** bridge nonce for your first message.
- [ ] If Mode C: read the target Safe's `nonce()`, `getThreshold()`, `getOwners()`. Save these — your tx hashes depend on them.
- [ ] Verify `MaticBridgeModule` is still enabled as a module on `0x208Fb` (Section 5.3).
- [ ] If touching the owner linked list: print `getOwners()` and decide the correct `prevOwner` for every removal. Owners are stored in a linked list ordered by insertion; `getOwners()` returns them in that order, so `prevOwner(X)` is whatever element precedes `X` in the returned array.

### 7.3 Encoding & generation

- [ ] Write the script under `contracts/deploy/03-config/<version>/`.
- [ ] **Read every nonce live**, don't hardcode them.
- [ ] If multiple actions: ensure bridge nonces are consecutive (`n, n+1, n+2, …`) in the order the messages must be processed.
- [ ] Run the script and produce the per-action JSON in `contracts/deployments/safe-transactions/`.

### 7.4 Simulation (Polygon)

- [ ] Fetch latest Polygon block.
- [ ] Fork at that block: `HARDHAT_FORKING_BLOCK=$LATEST_POLYGON`.
- [ ] Impersonate `fxChild`, fund it, call `MaticBridgeModule.processMessageFromRoot(0, daoMultisig, payload)` in order.
- [ ] Assert the post-state on Polygon matches expectations (owners, proxy implementations, parameter values, etc.).

### 7.5 Simulation (Ethereum)

- [ ] Fetch latest Ethereum block.
- [ ] Fork at that block: `HARDHAT_FORKING_BLOCK=$LATEST_ETH` (mandatory under Node.js v25).
- [ ] Impersonate `0x505796f5…`, send each Ethereum tx to FxRoot, assert success and presence of `StateSynced` event.

### 7.6 Output for Snapshot

- [ ] Produce a human-readable summary (header with addresses + Transactions Overview + Batch #1 layout).
- [ ] Produce a Gnosis Safe Transaction Builder JSON batch at the bottom: an array of `{to, operation, value, data}` objects (always `to = FxRoot`, `operation = "0"`, `value = "0.0"` for cross-chain proposals).
- [ ] Cross-check both representations byte-by-byte (script in Section 8.5).

### 7.7 Pre-submission verification (just before posting Snapshot proposal)

- [ ] Re-run Step 1 (Polygon simulation) at the absolute latest block. If the **simulated Safe tx hashes change**, regenerate the proposal. Stale calldata will revert on execution.
- [ ] Confirm no Safe transactions on the target are pending.
- [ ] Verify all addresses appear correctly in the human summary.

### 7.8 Execution

- [ ] Vote on Snapshot. Once it passes, load the JSON batch into Gnosis Safe Transaction Builder (https://app.safe.global) targeting `0x505796f5…` on Ethereum.
- [ ] First signer reviews each tx in the batch (tx 1's selector should be `0xb4720477` to `FxRoot`).
- [ ] Collect 2 signatures, execute, capture all 4 Ethereum tx hashes.

### 7.9 Post-execution verification

- [ ] On Ethereum: for each tx, confirm `StateSynced` was emitted.
- [ ] On Polygon: wait until each state sync is processed (typically ~22 min per checkpoint). Watch the MaticBridgeModule address for incoming calls.
- [ ] After all bridge calls land, verify the target state on Polygon:
  - For Safe-owner changes: `getOwners()` and `getThreshold()` match the intended final state.
  - For proxy upgrades: read the EIP-1967 implementation slot.
  - For parameter updates: call the getter and confirm the new value.
- [ ] Read `MaticBridgeModule.nonce()` and confirm it advanced by the expected number of messages.

### 7.10 Rollback considerations

- There is no rollback once a bridge message is delivered. The only way to undo a change is to ship a counter-proposal.
- If a proposal is signed on Ethereum but bridge delivery has not yet completed, you cannot abort. Polygon will eventually process it.
- The safest mitigations are: (a) thorough fork simulation, (b) byte-for-byte cross-check of generated calldata, (c) verifying live state did not drift between generation and execution.

---

## 8. Failure Modes & Gotchas

### 8.1 Nonce drift (the #1 source of bugs)

- **Target Safe nonce**: Every `execTransaction` on a Safe consumes one nonce. The Safe tx hash is computed over the nonce. If any other transaction lands on the target Safe between your simulation and the bridge delivery, **your Safe tx hashes are invalid and the bridge messages will revert at the Safe**.
- **MaticBridgeModule nonce**: The module's internal `nonce()` is a strictly-increasing counter. If anyone else sends a message through MaticBridgeModule with `nonce = N` before your messages start, your first message reverts.
- **Mitigation**: regenerate immediately before signing. Read `nonce()` live. Coordinate with anyone else who might send a governance action.

### 8.2 Owner linked-list ordering

- Safe owners are stored in a circular linked list. `removeOwner(prevOwner, owner, newThreshold)` requires `prevOwner.next == owner` at execution time.
- The list shifts as removals happen. If you remove A then B, `prevOwner(B)` is whatever currently precedes B (possibly the SENTINEL if A came before B and B was second).
- **Mitigation**: simulate every removal in sequence and let the simulation tell you the right `prevOwner`. Do not hand-compute. The PIP-32 reference simulation got both `prevOwner` values right by following the post-removal list state.

### 8.3 Wrong execution mode

- Calling Mode B encoding on a Safe target (e.g., directly invoking `removeOwner` on `ownerSafeDao` without `execTransaction`) will revert with `GS031` (only `address(this)`) or similar Safe error.
- Calling Mode C encoding on a non-Safe target wastes nonces and reverts because `approveHash` does not exist on the target.

### 8.4 Wrong `rootMessageSender`

- MaticBridgeModule rejects payloads whose `rootMessageSender != 0x505796f5…`. Only the Ethereum DAO Multisig can produce valid bridge messages. Any other Ethereum address calling FxRoot will produce no on-chain effect on Polygon.

### 8.5 Calldata divergence between sections

- `proposal_txs_data.txt` has the same calldata in two places — a human-readable "Tx #N" block and the JSON batch at the bottom. They MUST be identical byte-for-byte. Verify with:

```python
import json, re
with open('proposal_txs_data.txt') as f:
    content = f.read()
section = [l.strip() for l in content.split('\n') if l.strip().startswith('0xb4720477')]
batch = re.findall(r'"data":\s*"(0xb4720477[a-f0-9]+)"', content)
assert section == batch, "section/batch mismatch — DO NOT SUBMIT"

# Strict-JSON guard — catches `// label` comments leaking into the arrays.
arrays = re.findall(r'(?:Batch Transaction Hash:|Batch #\d+ — JSON[^\n]*\*\*).*?\n\s*(\[.*?\n    \])', content, re.S)
for txt in arrays:
    json.loads(txt)
```

### 8.6 Fork-block staleness

- Hardhat caches fork state in `contracts/cache/hardhat-network-fork`. Running consecutive tasks against different RPC URLs (e.g., Polygon then Ethereum) without specifying a block may try to reuse a cached snapshot at the wrong block number. Pass `HARDHAT_FORKING_BLOCK` explicitly — never rely on a previously-set env var that may be stale.

### 8.7 Hardhat + Node.js v25

- Forking Ethereum at "latest" without `HARDHAT_FORKING_BLOCK` fails with `NETWORK_ERROR: could not detect network`. Always set `HARDHAT_FORKING_BLOCK` for Ethereum forks. (Polygon fork at latest works without it but is also safer to pin.)

### 8.8 Asymmetric authority

- `ownerSafeDao` is effectively controlled by **two** quorums (per Section 1.4): 2-of-4 on Polygon Multisig and 2-of-5 on Ethereum DAO Multisig via the bridge. Compromise of either can move funds or change configuration. Plan signer changes on both sides together.

### 8.9 Ordering between messages

- Bridge messages with consecutive nonces must arrive (and be processed) in order. The state sync from Polygon validators preserves order under normal conditions, but if you sign and execute all FxRoot transactions in a single Ethereum tx-builder batch, they're submitted in the same Ethereum block, which preserves order. If you split them into separate Ethereum transactions, **execute them in the right block order**.

### 8.10 The "operation" field

- Bridge payloads encode an `operation` byte. Always use `0` (CALL) unless you are intentionally executing a delegatecall, which is extremely rare and dangerous in this context.

---

## 9. Security Considerations

### 9.1 Privileged operations

The following actions are reachable through governance and have systemic blast radius:

- Adding/removing owners on `ownerSafeDao`, `0x208Fb…`, or `0x505796f5…` (alters threshold authority).
- Disabling the MaticBridgeModule on `0x208Fb`. If executed, the cross-chain path is irrecoverable from Ethereum — only direct Polygon signing can restore it.
- Replacing implementations of EIP-1967 proxies (FeeMaster, Vault, Paymaster). A buggy implementation can corrupt user balances or freeze funds.
- Updating fee parameters, treasury destinations, or trust providers.

For any of the above, simulation MUST be performed on a fresh latest-block fork, AND a counter-fork that verifies the immediately-prior block had the same starting state.

### 9.2 Sensitive keys

- Private keys for signers of `0x208Fb…` and `0x505796f5…` are the highest-value secrets in this system. They are held by the protocol foundation and never appear in this repo.
- Local fork tasks NEVER need a real signer key; they use Hardhat's account impersonation. Do not paste private keys into a fork task.

### 9.3 Verification expectations

Before any proposal is submitted, you should have, at minimum:

1. Live read of all relevant on-chain state, captured in the simulation log.
2. A passing Polygon fork simulation at the latest block.
3. A passing Ethereum fork simulation at the latest block.
4. A byte-for-byte equality check between the per-tx "Data" sections and the JSON batch.
5. A re-read of nonces immediately before Snapshot submission to confirm no drift.

### 9.4 Blast radius of common mistakes

| Mistake                                           | Blast radius                                                                                                                           |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Stale Safe nonce in calldata                      | Bridge messages revert on Polygon. Bridge nonce is still consumed → must re-issue a NEW proposal with the next available bridge nonce. |
| Stale bridge nonce                                | First bridge message reverts; subsequent ones queue invalid forever. Must re-issue.                                                    |
| Wrong `prevOwner`                                 | `removeOwner` reverts on Polygon. Bridge nonce consumed; must re-issue.                                                                |
| Wrong target address                              | Either reverts (best case) or executes a different (possibly destructive) action on the wrong contract.                                |
| Wrong `rootMessageSender` (sender not 0x505796f5) | No effect — MaticBridgeModule rejects. Wasted FxRoot tx + Ethereum gas.                                                                |
| Disabling MaticBridgeModule by accident           | Cross-chain governance disabled. Only fixable by direct Polygon 2-of-4 signing on `0x208Fb`.                                           |
| Wrong execution mode (Mode B on a Safe target)    | Reverts on Polygon; bridge nonces consumed; must re-issue.                                                                             |

### 9.5 Recoverability

- Polygon-only governance (`0x208Fb…` 2-of-4) is the fallback for fixing cross-chain breakage. Keep its signer set healthy.
- Ethereum DAO Multisig is the fallback for fixing Polygon-only breakage (it can always reach `ownerSafeDao` through the bridge as long as MaticBridgeModule is enabled).
- If both paths are broken simultaneously, governance is lost.

---

## 10. Quick Reference for AI Agents Preparing a New Proposal

The **goal of the agent is to produce a single `proposal_txs_data.txt` file** (Section 3.5) that has been:

- generated from a Polygon fork at the **latest live Polygon block**,
- verified on an Ethereum fork at the **latest live Ethereum block**,
- byte-for-byte cross-checked between its human-readable and JSON-batch sections.

The agent must NOT submit anything, broadcast anything, or treat the file as ready until the user has reviewed it.

### 10.1 Decision tree

When given **(this document) + (a goal)**, follow this sequence:

1. **Read the goal.** Identify target contract, method, args. Ask the user for any ambiguous parameters.
2. **Look up the target's owner on Polygon.**
   - `cast call <target> 'owner()(address)' --rpc-url $POLYGON_RPC` for EIP-173 proxies.
   - For Safe-administered contracts, the owner will eventually trace back to `0x208Fb` or `ownerSafeDao`.
3. **Pick the mode** (Section 1.3 table).
4. **Read live state** (Section 5.1–5.3). Capture: Safe nonces, bridge nonce, threshold, owners.
5. **Encode the action.** Use the `06-upgrade-vault-v1-proxy.ts` template for Mode B, or the `test-proposal.ts` pattern for Mode C. Always pass a freshly-read bridge nonce.
6. **Run the four-step pipeline from Section 3.5.4** to produce `tx-data.txt`:
   a. `eth_blockNumber` for Polygon → `HARDHAT_FORKING_BLOCK` → run `<proposal-id>-bridge`.
   b. Run `<proposal-id>-ethereum` to emit `tx-data.txt`.
   c. `eth_blockNumber` for Ethereum → `HARDHAT_FORKING_BLOCK` → run `<proposal-id>-test-ethereum`.
   d. Run the byte-for-byte equality check between the "Data:" section and the JSON batch.
7. **Validate the file's structure** matches the template in Section 3.5.2: header, addresses block, transactions overview, Tx #N blocks, JSON batch at the bottom.
8. **Ask the user to confirm** they reviewed: target address, function selector, args, bridge nonces, signer set, the human-readable summary.
9. **Hand the user the final `proposal_txs_data.txt`** for Snapshot submission. Remind the user to re-run the pipeline if any new transactions hit the target Safe or MaticBridgeModule before they submit.

Never sign or broadcast on behalf of the user. Never invent addresses or thresholds — always re-read them. Never use a cached fork block.

---

## 11. Bridging ERC20 value to Polygon (Polygon PoS canonical bridge)

Sections 1–10 cover the FxPortal **message** bridge (`FxRoot` → `FxChild` → `MaticBridgeModule`), used to deliver governance *instructions* from Ethereum to Polygon.

This section covers the **separate** Polygon PoS canonical bridge used to move actual ERC20 **value** (e.g. ZKP) from Ethereum to its mapped child-token on Polygon. The two bridges are independent: different contracts, different state, different nonces, different checkpoint queues.

### 11.1 Addresses (Ethereum side)

| Symbol                  | Address                                      | Purpose                                                                                                   |
| ----------------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `rootChainProxyManager` | `0xA0c68C638235ee32657e8f720a23ceC1bFc77C77` | Polygon PoS `RootChainManager`. Entry point for `depositFor`; emits the events Heimdall validators sync.  |
| `erc20PredicateProxy`   | `0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf` | ERC20 predicate. Pulls `rootToken` from `msg.sender` when `depositFor` runs (escrows the deposited value). |

The Polygon-side counterpart child token is determined by the bridge's pre-configured token map (set when the token was originally registered). For ZKP on Ethereum (`0x909E34d3…6a173`) the mapped child token is pZKP on Polygon (`0x9A06Db14…815EC`). `depositFor` does this routing automatically — you do not specify the child token.

### 11.2 Required Ethereum txs per deposit

```
1. (optional) acquire the ERC20 on Ethereum
       e.g. vPool.releaseTo(<poolId>, <holder>, amount)

2. <holder>: ERC20.approve(erc20PredicateProxy, amount)

3. <holder>: rootChainProxyManager.depositFor(
       address user        = <Polygon receiver, e.g. ownerSafeDao>,
       address rootToken   = <Ethereum-side ERC20, e.g. ZKP>,
       bytes   depositData = abi.encode(uint256 amount)
   )

4. (off-chain) wait ~22 min for the Heimdall checkpoint; the mapped child
   token is then credited to `user` on Polygon automatically.
```

Notes:

- `depositData` for an ERC20 is `abi.encode(uint256 amount)` — a single `uint256`. The predicate decodes this and pulls exactly `amount` from `msg.sender`.
- The `user` argument is the **Polygon-side receiver**, not the Ethereum sender. It can be any Polygon address (EOA, Safe, contract).
- The bridge maintains its own state-sync queue; it does **not** share `MaticBridgeModule.nonce`. A token deposit consumes no bridge-module nonce.

### 11.3 What you do NOT need

- No FxPortal / MaticBridgeModule involvement for the deposit leg. The DAO Multisig signs `approve` + `depositFor` directly on Ethereum.
- No Polygon-side governance action to *receive* the tokens — the ChildChainManager mints them to `user` automatically once the checkpoint lands.
- A Polygon-side governance call is only needed if you then need to *move* the tokens from the receiver. That follow-up is a normal Mode A / B / C action (Sections 1–10).

### 11.4 Selector reference (token bridge)

| Selector     | Function                                                                              |
| ------------ | ------------------------------------------------------------------------------------- |
| `0x095ea7b3` | `ERC20.approve(address spender, uint256 amount)`                                      |
| `0xe3dec8fb` | `RootChainManager.depositFor(address user, address rootToken, bytes depositData)`     |

### 11.5 Combined proposals (governance + token bridge)

A single Snapshot proposal often bundles multiple Ethereum txs that mix FxPortal *message* calls and Polygon PoS *value* deposits. PIP-31 is the canonical example: 5 txs total — `addVestingPools`, `updatePoolTime`, `releaseTo`, `approve`, `depositFor` — submitted as one Gnosis Safe Transaction Builder batch signed by the DAO Multisig.

In such a batch:

- Not every tx targets `FxRoot`. The byte-for-byte cross-check from §3.5.4 (which greps for `0xb4720477`) only applies to FxPortal entries — extend the check per-batch.
- Ordering matters within the Ethereum batch: `approve` must precede `depositFor`, and any Ethereum-side state mutation that produces tokens (`releaseTo`) must precede the `approve`.
- Bridge-side ordering still applies for the FxPortal entries (consecutive `MaticBridgeModule.nonce`).

### 11.6 Fork simulation

To rehearse the deposit on a forked Ethereum, impersonate the DAO Multisig and send the `approve` + `depositFor` transactions in sequence. Assert:

- `ERC20.allowance(holder, erc20PredicateProxy) >= amount` after step 2.
- `depositFor` succeeds and emits the bridge's `LockedERC20(...)` event.
- `ERC20.balanceOf(holder)` decreased by exactly `amount`.

The Polygon-side credit cannot be observed on the Ethereum fork — verification of the deposit leg alone is sufficient confidence for proposal review. Live post-execution verification requires reading `pZKP.balanceOf(user)` on Polygon ~22 minutes after the Ethereum tx confirms.

### 11.7 Reference

- PIP-31 reference task: `test.ts` at the repo root (mixes 3 vPool calls + `approve` + `depositFor` into one batch). Promote to `contracts/tasks/` when shipping.
- Polygon PoS bridge docs: https://docs.polygon.technology/pos/architecture/bridge/ (RootChainManager + ERC20 predicate).

---

## Appendix A — Selector Reference

| Selector     | Function                                                      |
| ------------ | ------------------------------------------------------------- |
| `0xb4720477` | `FxRoot.sendMessageToChild(address,bytes)`                    |
| `0xaffed0e0` | `nonce()` (Safe + MaticBridgeModule)                          |
| `0xe75235b8` | `Safe.getThreshold()`                                         |
| `0xa0e67e2b` | `Safe.getOwners()`                                            |
| `0x2d9ad53d` | `Safe.isModuleEnabled(address)`                               |
| `0xd4d9bdcd` | `Safe.approveHash(bytes32)`                                   |
| `0x6a761202` | `Safe.execTransaction(...)`                                   |
| `0xf8dc5dd9` | `Safe.removeOwner(address,address,uint256)`                   |
| `0x0d582f13` | `Safe.addOwnerWithThreshold(address,uint256)`                 |
| `0x694e80c3` | `Safe.changeThreshold(uint256)`                               |
| `0x3659cfe6` | `EIP-173 proxy upgradeTo(address)`                            |
| `0xe0a8f6f5` | `Safe.enableModule(address)`                                  |
| `0x5229073f` | `Safe.execTransactionFromModule(address,uint256,bytes,uint8)` |
| `0x095ea7b3` | `ERC20.approve(address,uint256)`                              |
| `0xe3dec8fb` | `RootChainManager.depositFor(address,address,bytes)`          |

## Appendix B — File pointers used in this document

- Bridge constants and ABIs: `contracts/deploy/03-config/utils.ts`
- Mode A example: `contracts/deploy/03-config/v0/03-upgrade-fee-master-proxy.ts`
- Mode B example: `contracts/deploy/03-config/v1/06-upgrade-vault-v1-proxy.ts`
- Mode C template: `contracts/tasks/test-proposal.ts`
- Ethereum-side fork verifier: `contracts/tasks/test-ethereum-txs.ts`
- Named-account map: `contracts/hardhat.config.ts` (`getNamedAccounts()`)
- Saved per-action Safe txs: `contracts/deployments/safe-transactions/<script-name>-<network>.json`
- PIP-32 operational guide: `contracts/tasks/README-pip-32.md`
- PIP-32 proposal text: `proposal_txs_data.txt` (repo root)
- PIP-31 ERC20 bridge example (RootChainManager `depositFor`): `test.ts` (repo root)
