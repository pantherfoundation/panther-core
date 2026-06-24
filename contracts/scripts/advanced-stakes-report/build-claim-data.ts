// Post-process the reconstruction output (stakes.json) into the
// claim-ready artifacts:
//
//   output/double-spends.json       — any leafId seen in >1 exit tx (FYI only).
//   output/unexited-per-leaf.json   — per-leaf record of unclaimed ZKP/NFT,
//                                     with the 10%/year gift on unclaimed ZKP.
//   output/claimable-per-user.json  — per-user aggregate ready for the Merkle
//                                     leaf, plus the Merkle proof for each.
//   output/merkle-summary.json      — root, total ZKP needed, NFTs needed,
//                                     gap vs current Vault/ARC balances.
//
// Gift rule (per user spec):
//   referenceTime = 2026-05-31 00:00:00 UTC (last day of May 2026)
//   yearSeconds   = 365 * 24 * 3600
//   gift_wei      = zkp_wei * (referenceTime - creationTime) / (10 * yearSeconds)
// Only applies to leaves whose ZKP has NOT been exited. Gift is in ZKP only;
// NFT side gets no gift.
//
// Leaf encoding (matches VaultV0Frozen.sol verbatim):
//   leaf = keccak256(bytes.concat(keccak256(abi.encode(
//             address user, uint256 zkpAmount, uint16 nftCount))))

import { BigNumber, utils } from "ethers";
import * as fs from "fs";
import * as path from "path";
import * as https from "https";
import { OUTPUT_DIR } from "./config";

// ---- Inputs ----
const STAKES_PATH = path.join(OUTPUT_DIR, "stakes.json");
const TX_CACHE_PATH = path.join(__dirname, "cache", "polygon-tx-inputs.json");

// Reference time: 2026-05-31 00:00 UTC.
const REFERENCE_TIME_UNIX = Math.floor(
    Date.UTC(2026, 4, 31) / 1000,
);
const YEAR_SECONDS = 365 * 24 * 3600;

// Vault / ARC balances at run time (queried separately and pasted in; not
// strictly required to build the artifacts, but used for the gap report).
// These are read live in the validation step below via direct RPC.
const VAULT = "0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9";
const ARC = "0x8f15a43961c27C74CB4F55234A78802401614de3";
const ZKP = "0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC";
const NFT = "0xE5da4955cBC480Eb9Bf9534def229F9D8339eE6d";
const POLYGON_RPC = "https://polygon-mainnet.g.alchemy.com/v2/-bbwqZtH2RJk3xclZ2ccJPa9yik86KQC";

interface StakeRecord {
    staker: string;
    leftLeafId: number | null;
    creationTime: string; // ISO
    exitTime: string;
    zkpRewards: string;
    nftRewards: string;
    zkpExited: boolean;
    nftExited: boolean;
    zkpExitTime: string | null;
    nftExitTime: string | null;
    sourceChain: "ethereum" | "polygon" | "unmatched-mainnet";
}

interface TxCacheEntry {
    data: string;
    blockNumber: number;
}

const loadJson = <T>(p: string): T =>
    JSON.parse(fs.readFileSync(p, "utf8")) as T;

const writeJson = (p: string, obj: unknown): void => {
    fs.writeFileSync(p, JSON.stringify(obj, null, 2));
    console.log(`wrote ${p}`);
};

// ---------- Double-spend detection ----------
//
// Walk the polygon-tx-inputs cache (tx → calldata for every Nullifier-emitting
// tx) and bucket the decoded leafId by tx. Flag any leafId appearing in two
// or more distinct exit transactions. The nullifier check on-chain prevents
// reuse of the SAME (privSpendingKey, leafId) tuple — but a flaw allowing two
// different privSpendingKeys to spend the same leafId would surface here.

const EXIT_SELECTOR = utils
    .id(
        "exit(address,uint256,uint64,uint32,uint256,uint256,bytes32[16],bytes32,uint256)",
    )
    .slice(0, 10);

const detectDoubleSpends = (): {
    perLeafId: Map<number, string[]>;
    doubleSpent: Array<{ leafId: number; txs: string[] }>;
} => {
    if (!fs.existsSync(TX_CACHE_PATH)) {
        throw new Error(`missing tx cache: ${TX_CACHE_PATH}`);
    }
    const txCache = loadJson<Record<string, TxCacheEntry>>(TX_CACHE_PATH);
    const perLeafId = new Map<number, string[]>();
    for (const [txHash, entry] of Object.entries(txCache)) {
        const data = entry.data;
        if (!data || !data.startsWith(EXIT_SELECTOR)) continue;
        // leafId is the 6th parameter (index 5). Each param is 32 bytes; 10 chars = '0x' + selector.
        const argsHex = data.slice(10);
        if (argsHex.length < 7 * 64) continue;
        const leafHex = argsHex.slice(5 * 64, 6 * 64);
        const leafId = BigNumber.from("0x" + leafHex).toNumber();
        const arr = perLeafId.get(leafId) ?? [];
        arr.push(txHash);
        perLeafId.set(leafId, arr);
    }
    const doubleSpent = [...perLeafId.entries()]
        .filter(([, txs]) => txs.length > 1)
        .map(([leafId, txs]) => ({ leafId, txs }));
    return { perLeafId, doubleSpent };
};

// ---------- Per-leaf unclaimed computation ----------

interface PerLeafRecord {
    leftLeafId: number;
    staker: string;
    sourceChain: string;
    creationTime: string;
    zkpReward: string;
    nftReward: number;
    zkpExited: boolean;
    nftExited: boolean;
    // computed:
    unclaimedZkp: string;
    zkpGift: string;
    zkpToReceive: string; // unclaimedZkp + zkpGift
    unclaimedNft: number;
    secondsHeld: number; // referenceTime - creationTime
}

const computeGift = (zkpWei: BigNumber, secondsHeld: number): BigNumber => {
    // gift = zkp * secondsHeld / (10 * YEAR_SECONDS)
    // Integer math: numerator first, then divide. zkp is at most ~10^25 wei,
    // secondsHeld <= ~5*YEAR_SECONDS, product fits in ~2^85 — safe in BigNumber.
    return zkpWei.mul(secondsHeld).div(BigNumber.from(10).mul(YEAR_SECONDS));
};

const buildPerLeaf = (
    stakes: StakeRecord[],
): { perLeaf: PerLeafRecord[]; dropped: number } => {
    const perLeaf: PerLeafRecord[] = [];
    let dropped = 0;
    for (const s of stakes) {
        if (s.leftLeafId === null) {
            // unmatched mainnet — no UTXO created; not claimable from Vault
            dropped += 1;
            continue;
        }

        const zkpRewardWei = BigNumber.from(s.zkpRewards);
        const nftReward = Number(s.nftRewards);

        const creationUnix = Math.floor(
            new Date(s.creationTime).getTime() / 1000,
        );
        const secondsHeld = Math.max(0, REFERENCE_TIME_UNIX - creationUnix);

        // Unclaimed: only if not yet exited.
        const unclaimedZkpWei = s.zkpExited
            ? BigNumber.from(0)
            : zkpRewardWei;
        const giftWei = s.zkpExited
            ? BigNumber.from(0)
            : computeGift(zkpRewardWei, secondsHeld);
        const unclaimedNft = !s.nftExited && nftReward > 0 ? 1 : 0;

        if (unclaimedZkpWei.isZero() && unclaimedNft === 0) {
            // Fully claimed already (e.g. zkpExited stake with nftReward == 0)
            dropped += 1;
            continue;
        }

        perLeaf.push({
            leftLeafId: s.leftLeafId,
            staker: s.staker,
            sourceChain: s.sourceChain,
            creationTime: s.creationTime,
            zkpReward: zkpRewardWei.toString(),
            nftReward,
            zkpExited: s.zkpExited,
            nftExited: s.nftExited,
            unclaimedZkp: unclaimedZkpWei.toString(),
            zkpGift: giftWei.toString(),
            zkpToReceive: unclaimedZkpWei.add(giftWei).toString(),
            unclaimedNft,
            secondsHeld,
        });
    }
    perLeaf.sort((a, b) => a.leftLeafId - b.leftLeafId);
    return { perLeaf, dropped };
};

// ---------- Per-user aggregation ----------

interface PerUserRecord {
    staker: string;
    totalZkp: string; // wei, includes gift
    nftCount: number;
    leftLeafIds: number[]; // informational
    // merkle:
    leaf: string;
    proof: string[];
}

const buildPerUser = (perLeaf: PerLeafRecord[]): PerUserRecord[] => {
    const byUser = new Map<
        string,
        { zkp: BigNumber; nfts: number; leafIds: number[] }
    >();
    for (const r of perLeaf) {
        const u = byUser.get(r.staker) ?? {
            zkp: BigNumber.from(0),
            nfts: 0,
            leafIds: [],
        };
        u.zkp = u.zkp.add(r.zkpToReceive);
        u.nfts += r.unclaimedNft;
        u.leafIds.push(r.leftLeafId);
        byUser.set(r.staker, u);
    }
    // Sort by staker for deterministic order. Merkle leaves are sorted later.
    const out: PerUserRecord[] = [];
    for (const [staker, u] of byUser) {
        out.push({
            staker,
            totalZkp: u.zkp.toString(),
            nftCount: u.nfts,
            leftLeafIds: u.leafIds.sort((a, b) => a - b),
            leaf: "",
            proof: [],
        });
    }
    out.sort((a, b) => (a.staker < b.staker ? -1 : 1));
    return out;
};

// ---------- Merkle tree (OZ-compatible: sorted pair hashes, double-hashed leaf) ----------

const leafHash = (
    user: string,
    zkpAmount: BigNumber,
    nftCount: number,
): string => {
    const inner = utils.keccak256(
        utils.defaultAbiCoder.encode(
            ["address", "uint256", "uint16"],
            [user, zkpAmount, nftCount],
        ),
    );
    // bytes.concat(keccak256(...)) is just keccak256 of the inner bytes.
    return utils.keccak256(inner);
};

const sortedPair = (a: string, b: string): string => {
    const [x, y] = a.toLowerCase() < b.toLowerCase() ? [a, b] : [b, a];
    return utils.keccak256(utils.concat([x, y]));
};

const buildMerkle = (
    leaves: string[],
): {
    root: string;
    proofs: Map<string, string[]>;
    layers: string[][];
} => {
    if (leaves.length === 0) {
        throw new Error("no leaves");
    }
    // Build layers bottom-up
    const layers: string[][] = [leaves.slice()];
    while (layers[layers.length - 1].length > 1) {
        const prev = layers[layers.length - 1];
        const next: string[] = [];
        for (let i = 0; i < prev.length; i += 2) {
            if (i + 1 === prev.length) {
                next.push(prev[i]); // odd node promoted unchanged
            } else {
                next.push(sortedPair(prev[i], prev[i + 1]));
            }
        }
        layers.push(next);
    }
    const root = layers[layers.length - 1][0];

    // Build proof per leaf
    const proofs = new Map<string, string[]>();
    for (let leafIdx = 0; leafIdx < leaves.length; leafIdx += 1) {
        const proof: string[] = [];
        let idx = leafIdx;
        for (let level = 0; level < layers.length - 1; level += 1) {
            const layer = layers[level];
            const isLast = idx === layer.length - 1;
            if (isLast && layer.length % 2 === 1) {
                // odd promoted — no sibling at this level
                idx = Math.floor(idx / 2);
                continue;
            }
            const siblingIdx = idx % 2 === 0 ? idx + 1 : idx - 1;
            proof.push(layer[siblingIdx]);
            idx = Math.floor(idx / 2);
        }
        proofs.set(leaves[leafIdx], proof);
    }

    return { root, proofs, layers };
};

// ---------- Verify a proof locally (sanity) ----------

const verifyProof = (
    leaf: string,
    proof: string[],
    root: string,
): boolean => {
    let cur = leaf;
    for (const sib of proof) cur = sortedPair(cur, sib);
    return cur.toLowerCase() === root.toLowerCase();
};

// ---------- Live balance lookup ----------

const httpPostJson = (url: string, body: object): Promise<any> =>
    new Promise((resolve, reject) => {
        const data = JSON.stringify(body);
        // Naive URL parse: scheme://host/path. Avoids relying on URL global.
        const m = url.match(/^https:\/\/([^/]+)(\/.*)?$/);
        if (!m) {
            reject(new Error("invalid url"));
            return;
        }
        const hostname = m[1];
        const path = m[2] || "/";
        const req = https.request(
            {
                method: "POST",
                hostname,
                path,
                headers: {
                    "Content-Type": "application/json",
                    "Content-Length": Buffer.byteLength(data),
                },
            },
            (res) => {
                const chunks: Buffer[] = [];
                res.on("data", (c) => chunks.push(c));
                res.on("end", () => {
                    try {
                        resolve(JSON.parse(Buffer.concat(chunks).toString()));
                    } catch (e) {
                        reject(e);
                    }
                });
            },
        );
        req.on("error", reject);
        req.write(data);
        req.end();
    });

const fetchBalance = async (
    token: string,
    holder: string,
): Promise<BigNumber> => {
    const data =
        "0x70a08231" + "000000000000000000000000" + holder.slice(2);
    const body = {
        jsonrpc: "2.0",
        method: "eth_call",
        params: [{ to: token, data }, "latest"],
        id: 1,
    };
    const resp = await httpPostJson(POLYGON_RPC, body);
    return BigNumber.from(resp.result);
};

// ---------- Orchestrate ----------

const main = async (): Promise<void> => {
    if (!fs.existsSync(STAKES_PATH))
        throw new Error(`missing ${STAKES_PATH} — run index.ts first`);
    const stakes = loadJson<StakeRecord[]>(STAKES_PATH);
    console.log(`loaded ${stakes.length} stakes`);
    console.log(
        `reference time (gift end): ${new Date(REFERENCE_TIME_UNIX * 1000).toISOString()} (unix ${REFERENCE_TIME_UNIX})`,
    );

    // 1) Double-spend scan
    const { doubleSpent } = detectDoubleSpends();
    writeJson(path.join(OUTPUT_DIR, "double-spends.json"), {
        count: doubleSpent.length,
        records: doubleSpent,
    });
    if (doubleSpent.length > 0) {
        console.warn(
            `\n*** WARNING *** ${doubleSpent.length} double-spent leafIds detected.`,
        );
        for (const d of doubleSpent.slice(0, 10)) {
            console.warn(
                `   leafId=${d.leafId} txs=${d.txs.join(",")}`,
            );
        }
    } else {
        console.log("no leafId double-spends");
    }

    // 2) Per-leaf unclaimed
    const { perLeaf, dropped } = buildPerLeaf(stakes);
    writeJson(path.join(OUTPUT_DIR, "unexited-per-leaf.json"), {
        referenceTimeUnix: REFERENCE_TIME_UNIX,
        referenceTimeIso: new Date(REFERENCE_TIME_UNIX * 1000).toISOString(),
        yearSeconds: YEAR_SECONDS,
        count: perLeaf.length,
        droppedFullyClaimed: dropped,
        leaves: perLeaf,
    });
    console.log(
        `per-leaf: ${perLeaf.length} leaves with unclaimed assets (${dropped} dropped as fully claimed / unmatched)`,
    );

    // 3) Per-user aggregate
    const perUser = buildPerUser(perLeaf);

    // 4) Merkle tree
    for (const u of perUser) {
        u.leaf = leafHash(u.staker, BigNumber.from(u.totalZkp), u.nftCount);
    }
    const leafList = perUser.map((u) => u.leaf);
    const { root, proofs } = buildMerkle(leafList);
    for (const u of perUser) {
        u.proof = proofs.get(u.leaf) ?? [];
        if (!verifyProof(u.leaf, u.proof, root))
            throw new Error(`proof verify failed for ${u.staker}`);
    }

    // 5) Totals + invariants
    let totalZkpNeeded = BigNumber.from(0);
    let totalNftNeeded = 0;
    for (const u of perUser) {
        totalZkpNeeded = totalZkpNeeded.add(u.totalZkp);
        totalNftNeeded += u.nftCount;
    }
    // Breakdown principal vs gift.
    let totalPrincipal = BigNumber.from(0);
    let totalGift = BigNumber.from(0);
    for (const l of perLeaf) {
        totalPrincipal = totalPrincipal.add(l.unclaimedZkp);
        totalGift = totalGift.add(l.zkpGift);
    }
    if (totalNftNeeded !== 2000) {
        console.warn(
            `*** WARN *** total NFT to dispense = ${totalNftNeeded}, expected 2000`,
        );
    }

    writeJson(path.join(OUTPUT_DIR, "claimable-per-user.json"), {
        root,
        userCount: perUser.length,
        totalZkpNeededWei: totalZkpNeeded.toString(),
        totalNftNeeded,
        users: perUser,
    });

    // 6) Live balance + gap
    console.log("\nFetching live balances…");
    const vaultZkp = await fetchBalance(ZKP, VAULT);
    const vaultNft = await fetchBalance(NFT, VAULT);
    const arcZkp = await fetchBalance(ZKP, ARC);

    const zkpGap = totalZkpNeeded.sub(vaultZkp);
    const summary = {
        root,
        referenceTimeIso: new Date(REFERENCE_TIME_UNIX * 1000).toISOString(),
        userCount: perUser.length,
        leafCount: perLeaf.length,
        totals: {
            zkpNeededWei: totalZkpNeeded.toString(),
            zkpPrincipalWei: totalPrincipal.toString(),
            zkpGiftWei: totalGift.toString(),
            nftNeeded: totalNftNeeded,
        },
        balances: {
            vaultZkpWei: vaultZkp.toString(),
            vaultNft: vaultNft.toNumber(),
            arcZkpWei: arcZkp.toString(),
        },
        gap: {
            zkpGapWei: zkpGap.toString(), // positive = need to top up
            arcCoversGap: zkpGap.lte(0)
                ? true
                : zkpGap.lte(arcZkp),
            arcZkpAfterTopUp: zkpGap.lte(0)
                ? arcZkp.toString()
                : arcZkp.sub(zkpGap).toString(),
            arcZkpWithdrawNeededWei: zkpGap.lte(0)
                ? "0"
                : zkpGap.toString(),
        },
        doubleSpents: doubleSpent.length,
    };
    writeJson(path.join(OUTPUT_DIR, "merkle-summary.json"), summary);

    console.log("\n===== SUMMARY =====");
    console.log(`Merkle root:        ${root}`);
    console.log(`Users:              ${perUser.length}`);
    console.log(`Leaves (per-stake): ${perLeaf.length}`);
    console.log(
        `ZKP needed:         ${utils.formatEther(totalZkpNeeded)} ZKP`,
    );
    console.log(`NFTs needed:        ${totalNftNeeded}`);
    console.log(
        `Vault ZKP balance:  ${utils.formatEther(vaultZkp)} ZKP`,
    );
    console.log(
        `Vault NFT balance:  ${vaultNft.toNumber()} NFTs`,
    );
    console.log(`ARC ZKP balance:    ${utils.formatEther(arcZkp)} ZKP`);
    if (zkpGap.lte(0)) {
        console.log(`Vault is sufficient — no ARC withdrawal needed.`);
    } else {
        console.log(
            `ZKP gap:            ${utils.formatEther(zkpGap)} ZKP (need to withdraw from ARC)`,
        );
        if (zkpGap.lte(arcZkp)) {
            console.log(
                `ARC covers gap:     YES (ARC has ${utils.formatEther(arcZkp)}, need ${utils.formatEther(zkpGap)})`,
            );
        } else {
            console.log(
                `*** SHORTFALL ***   ARC has ${utils.formatEther(arcZkp)} but gap is ${utils.formatEther(zkpGap)}.`,
            );
            console.log(
                `                    Vault + ARC TOTAL: ${utils.formatEther(vaultZkp.add(arcZkp))} ZKP`,
            );
            console.log(
                `                    Still short by ${utils.formatEther(zkpGap.sub(arcZkp))} ZKP.`,
            );
        }
    }
};

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
