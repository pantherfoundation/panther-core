// Build the Merkle tree for VaultV0Frozen.claim from output/stakes.json.
//
// Steps:
//   1. Aggregate stakes.json per user into (zkpClaimable, nftCount). Stakes that
//      already had zkpExited / nftExited are excluded from the corresponding
//      side. `sourceChain: "unmatched-mainnet"` rows are excluded entirely
//      (no UTXO ever existed for them).
//   2. Build a sorted-pair (OZ-compatible) Merkle tree over leaves
//        leaf = keccak256(keccak256(abi.encode(user, zkpAmount, nftCount)))
//      with the "duplicate last when odd" rule for tree construction so all
//      paths share the same length.
//   3. Verify invariants against the live Polygon Vault:
//        Σ zkpAmount == Vault.ZKP.balanceOf
//        Σ nftCount  == 2000  (and Vault.NFT.balanceOf == 2000, ownerOf(1),
//                              ownerOf(1000), ownerOf(2000) all == Vault)
//   4. Emit:
//        output/merkle/root.json          (root + summary)
//        output/merkle/claims.json        (mapping address -> proof + amounts)
//
// Run from contracts/:
//   npx ts-node scripts/advanced-stakes-report/build-merkle.ts

import { BigNumber, providers, utils } from "ethers";
import * as fs from "fs";
import * as path from "path";
import { CHAINS, OUTPUT_DIR } from "./config";

// Polygon addresses (live).
const VAULT_PROXY = "0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9";
const ZKP_TOKEN = "0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC"; // PZkpToken
const NFT_TOKEN = "0xE5da4955cBC480Eb9Bf9534def229F9D8339eE6d"; // PNftToken
const FIRST_NFT_ID = 1;
const LAST_NFT_ID = 2000;

// --- Inputs ---

interface OutputStake {
    staker: string;
    leftLeafId: number | null;
    creationTime: string;
    exitTime: string;
    zkpRewards: string;
    nftRewards: string;
    zkpExited: boolean;
    nftExited: boolean;
    zkpExitTime: string | null;
    nftExitTime: string | null;
    sourceChain: "ethereum" | "polygon" | "unmatched-mainnet";
}

interface UserEntitlement {
    user: string; // lowercase
    zkpAmount: string; // wei, decimal string
    nftCount: number;
    sources: number; // # of stake records aggregated
}

// --- Step 1: aggregate per user ---

const stakesPath = path.join(OUTPUT_DIR, "stakes.json");
const stakes: OutputStake[] = JSON.parse(
    fs.readFileSync(stakesPath, "utf8"),
);

const entByUser = new Map<string, UserEntitlement>();
for (const s of stakes) {
    if (s.sourceChain === "unmatched-mainnet") continue;
    const u = s.staker.toLowerCase();
    let e = entByUser.get(u);
    if (!e) {
        e = { user: u, zkpAmount: "0", nftCount: 0, sources: 0 };
        entByUser.set(u, e);
    }
    e.sources += 1;
    if (!s.zkpExited && BigNumber.from(s.zkpRewards).gt(0)) {
        e.zkpAmount = BigNumber.from(e.zkpAmount)
            .add(s.zkpRewards)
            .toString();
    }
    if (!s.nftExited && BigNumber.from(s.nftRewards).gt(0)) {
        e.nftCount += 1;
    }
}

// Drop users with both sides zero (shouldn't happen given the inputs, but be safe).
const entitlements: UserEntitlement[] = [...entByUser.values()]
    .filter((e) => BigNumber.from(e.zkpAmount).gt(0) || e.nftCount > 0)
    .sort((a, b) => (a.user < b.user ? -1 : 1));

console.log(`unique users with entitlement: ${entitlements.length}`);
const totalZkp = entitlements.reduce(
    (acc, e) => acc.add(e.zkpAmount),
    BigNumber.from(0),
);
const totalNft = entitlements.reduce((acc, e) => acc + e.nftCount, 0);
console.log(`Σ zkpClaimable: ${totalZkp.toString()}`);
console.log(`Σ nftClaimable: ${totalNft}`);

// --- Step 2: build sorted-pair Merkle tree ---

const leafFor = (e: UserEntitlement): string => {
    const inner = utils.keccak256(
        utils.defaultAbiCoder.encode(
            ["address", "uint256", "uint16"],
            [e.user, e.zkpAmount, e.nftCount],
        ),
    );
    return utils.keccak256(inner);
};

const hashPair = (a: string, b: string): string => {
    const [lo, hi] =
        BigInt(a) < BigInt(b) ? [a, b] : [b, a];
    return utils.keccak256(utils.concat([lo, hi]));
};

// Tree stored as levels[0] = leaves, levels[depth] = [root].
const buildTree = (leaves: string[]): string[][] => {
    if (leaves.length === 0) throw new Error("empty leaves");
    const levels: string[][] = [leaves.slice()];
    while (levels[levels.length - 1].length > 1) {
        const cur = levels[levels.length - 1];
        const next: string[] = [];
        for (let i = 0; i < cur.length; i += 2) {
            const a = cur[i];
            // Duplicate last on odd — keeps proof lengths uniform and is
            // accepted by OZ's MerkleProof (which is commutative on pairs).
            const b = i + 1 < cur.length ? cur[i + 1] : cur[i];
            next.push(hashPair(a, b));
        }
        levels.push(next);
    }
    return levels;
};

const proofFor = (levels: string[][], index: number): string[] => {
    const proof: string[] = [];
    let idx = index;
    for (let lvl = 0; lvl < levels.length - 1; lvl++) {
        const layer = levels[lvl];
        const siblingIdx = idx ^ 1;
        const sibling = siblingIdx < layer.length ? layer[siblingIdx] : layer[idx];
        proof.push(sibling);
        idx = Math.floor(idx / 2);
    }
    return proof;
};

const leaves = entitlements.map(leafFor);
const levels = buildTree(leaves);
const root = levels[levels.length - 1][0];
console.log(`leaves: ${leaves.length}`);
console.log(`tree depth: ${levels.length - 1}`);
console.log(`root: ${root}`);

// Self-check: verify proof for every leaf against the root.
const verifyProof = (
    leaf: string,
    proof: string[],
    expectedRoot: string,
): boolean => {
    let computed = leaf;
    for (const p of proof) computed = hashPair(computed, p);
    return computed === expectedRoot;
};

for (let i = 0; i < entitlements.length; i++) {
    const ok = verifyProof(leaves[i], proofFor(levels, i), root);
    if (!ok) throw new Error(`self-check failed for index ${i}`);
}
console.log(
    `self-check: all ${entitlements.length} proofs verify against the root`,
);

// --- Step 3: verify against on-chain Vault state ---

const provider = new providers.JsonRpcProvider(CHAINS.polygon.rpc);
const erc20 = new utils.Interface([
    "function balanceOf(address) view returns (uint256)",
]);
const erc721 = new utils.Interface([
    "function balanceOf(address) view returns (uint256)",
    "function ownerOf(uint256) view returns (address)",
]);

const ethCall = async (
    to: string,
    iface: utils.Interface,
    fn: string,
    args: unknown[],
): Promise<utils.Result> => {
    const data = iface.encodeFunctionData(fn, args);
    const raw = await provider.call({ to, data });
    return iface.decodeFunctionResult(fn, raw);
};

const verifyOnChain = async (): Promise<void> => {
    console.log("\nverifying invariants against the live Polygon Vault…");

    const [zkpBalRaw] = await ethCall(
        ZKP_TOKEN,
        erc20,
        "balanceOf",
        [VAULT_PROXY],
    );
    const zkpBal = BigNumber.from(zkpBalRaw);
    console.log(`  ZKP balance:      ${zkpBal.toString()}`);
    console.log(`  Σ zkpClaimable:   ${totalZkp.toString()}`);
    if (!zkpBal.eq(totalZkp)) {
        const diff = zkpBal.sub(totalZkp);
        console.warn(
            `  ⚠ MISMATCH: vault has ${diff.toString()} more (positive) / fewer (negative) ZKP than entitlement`,
        );
    } else {
        console.log("  ✓ ZKP balance matches Σ entitlement");
    }

    const [nftBalRaw] = await ethCall(
        NFT_TOKEN,
        erc721,
        "balanceOf",
        [VAULT_PROXY],
    );
    const nftBal = BigNumber.from(nftBalRaw).toNumber();
    console.log(`  NFT balance:      ${nftBal}`);
    console.log(`  Σ nftClaimable:   ${totalNft}`);
    if (nftBal !== totalNft) {
        console.warn(`  ⚠ MISMATCH: vault has ${nftBal - totalNft} NFTs more/fewer than entitlement`);
    } else {
        console.log("  ✓ NFT count matches Σ entitlement");
    }

    // Spot-check NFT ownership at boundaries and a midpoint.
    const spotIds = [
        FIRST_NFT_ID,
        Math.floor((FIRST_NFT_ID + LAST_NFT_ID) / 2),
        LAST_NFT_ID,
    ];
    for (const id of spotIds) {
        const [owner] = await ethCall(NFT_TOKEN, erc721, "ownerOf", [id]);
        const ok = (owner as string).toLowerCase() === VAULT_PROXY.toLowerCase();
        console.log(`  ownerOf(${id}) == vault: ${ok ? "✓" : "✗ " + owner}`);
        if (!ok) {
            console.warn(
                `  ⚠ tokenId ${id} not held by vault; cursor-based dispensation will revert.`,
            );
        }
    }
};

// --- Step 4: emit outputs ---

const merkleDir = path.join(OUTPUT_DIR, "merkle");
fs.mkdirSync(merkleDir, { recursive: true });

interface ClaimEntry {
    user: string;
    zkpAmount: string;
    nftCount: number;
    proof: string[];
}

const claims: Record<string, ClaimEntry> = {};
for (let i = 0; i < entitlements.length; i++) {
    const e = entitlements[i];
    claims[e.user] = {
        user: e.user,
        zkpAmount: e.zkpAmount,
        nftCount: e.nftCount,
        proof: proofFor(levels, i),
    };
}

fs.writeFileSync(
    path.join(merkleDir, "root.json"),
    JSON.stringify(
        {
            root,
            depth: levels.length - 1,
            leafCount: entitlements.length,
            totalZkp: totalZkp.toString(),
            totalNft,
            firstNftId: FIRST_NFT_ID,
            lastNftId: LAST_NFT_ID,
        },
        null,
        2,
    ),
);
fs.writeFileSync(
    path.join(merkleDir, "claims.json"),
    JSON.stringify(claims, null, 2),
);
console.log(`\nwrote ${path.join(merkleDir, "root.json")}`);
console.log(`wrote ${path.join(merkleDir, "claims.json")}`);

verifyOnChain()
    .then(() => console.log("\ndone."))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });
