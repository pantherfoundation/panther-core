// Reconstruct all advanced staking positions across Ethereum + Polygon.
//
// Output: output/stakes.json — one record per stake, ordered by leftLeafId.
// Also: output/report.txt — integrity checks and summary statistics.
//
// Run with:
//   npx ts-node contracts/scripts/advanced-stakes-report/index.ts
//
// Re-runs are safe: cache/*.json holds previously-fetched logs and is appended
// to on each run. To force a full refetch, delete cache/.

import {BigNumber, utils} from 'ethers';
import * as fs from 'fs';
import * as path from 'path';
import {
    CHAINS,
    isAdvancedStakeType,
    OUTPUT_DIR,
    POLYGON_ARC_ADDRESS,
    POLYGON_ARC_DEPLOY_BLOCK,
    POLYGON_PANTHER_POOL_ADDRESS,
    POLYGON_PANTHER_POOL_DEPLOY_BLOCK,
} from './config';
import {
    getHeadBlock,
    getLogsCached,
    getTransactionInput,
    loadTxCache,
    saveTxCache,
} from './fetcher';

// ---------- Event ABIs ----------

const stakingIface = new utils.Interface([
    'event StakeCreated(address indexed account, uint256 indexed stakeID, uint256 amount, bytes4 stakeType, uint256 lockedTill)',
]);
const arcIface = new utils.Interface([
    'event RewardGenerated(address indexed staker, uint256 firstLeafId, uint256 zkp, uint256 nft)',
]);
const poolIface = new utils.Interface([
    'event NewCommitments(uint256 indexed leftLeafId, uint256 creationTime, bytes32[3] commitments, bytes utxoData)',
    'event Nullifier(bytes32 nullifier)',
]);

const exitIface = new utils.Interface([
    'function exit(address token, uint256 subId, uint64 scaledAmount, uint32 creationTime, uint256 privSpendingKey, uint256 leafId, bytes32[16] pathElements, bytes32 merkleRoot, uint256 cacheIndexHint) external',
]);
const EXIT_SELECTOR = exitIface.getSighash('exit');

const topic0 = (signature: string): string =>
    utils.id(signature.replace(/\s+/g, ''));

const TOPICS = {
    StakeCreated: topic0(
        'StakeCreated(address,uint256,uint256,bytes4,uint256)',
    ),
    RewardGenerated: topic0('RewardGenerated(address,uint256,uint256,uint256)'),
    NewCommitments: topic0('NewCommitments(uint256,uint256,bytes32[3],bytes)'),
    Nullifier: topic0('Nullifier(bytes32)'),
};

// ---------- Types ----------

interface AdvancedStake {
    chain: 'ethereum' | 'polygon';
    staker: string;
    stakeID: string;
    amount: string;
    stakeType: string;
    stakedAt: number; // block.timestamp at StakeCreated
    lockedTill: number;
    blockNumber: number;
    txHash: string;
}

interface RewardRecord {
    staker: string;
    leftLeafId: number;
    zkp: string;
    nft: string;
    blockNumber: number;
    creationTime: number; // from RewardGenerated tx block / NewCommitments
    txHash: string;
}

interface ExitRecord {
    leafId: number;
    leftLeafId: number;
    slot: number; // 0 = ZKP, 1 = NFT
    exitTime: number; // block.timestamp
    txHash: string;
    blockNumber: number;
}

interface OutputStake {
    staker: string;
    leftLeafId: number | null;
    creationTime: string; // ISO
    exitTime: string; // ISO, falls back to today 00:00 GMT
    zkpRewards: string;
    nftRewards: string;
    // Extras useful for audit:
    zkpExited: boolean;
    nftExited: boolean;
    zkpExitTime: string | null;
    nftExitTime: string | null;
    sourceChain: 'ethereum' | 'polygon' | 'unmatched-mainnet';
}

// ---------- Helpers ----------

const toIso = (unix: number): string => new Date(unix * 1000).toISOString();

const todayMidnightUtc = (): number => {
    const d = new Date();
    return Math.floor(
        Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) / 1000,
    );
};

// ---------- Phase 1: Stakes ----------
//
// Strategy:
//  - For mainnet: filter StakeCreated to advanced stake types we know about
//    (V1 = 0x7ec13a06). Mainnet never had a V2 adviser deployed, so this is
//    sufficient. Used to detect bridged stakes that lost their reward.
//  - For polygon: take ALL StakeCreated and use them as a tx-hash → stake index.
//    The owner has added new stake-type IDs over time (e.g. 0x466b3169) that
//    aren't in our source constants; filtering by hardcoded ID misses them.
//    The authoritative signal for "this stake got an advanced reward" is the
//    RewardGenerated event in the same tx — we match on that.

const collectStakes = async (
    chainId: 'ethereum' | 'polygon',
    filterAdvancedTypes: boolean,
): Promise<AdvancedStake[]> => {
    const chain = CHAINS[chainId];
    const head = await getHeadBlock(chain);
    console.log(
        `[${chainId}] fetching StakeCreated from ${chain.stakingDeployBlock} to ${head}`,
    );
    const logs = await getLogsCached(
        chain,
        chain.stakingAddress,
        TOPICS.StakeCreated,
        chain.stakingDeployBlock,
        head,
    );
    console.log(`[${chainId}] StakeCreated logs: ${logs.length}`);

    const out: AdvancedStake[] = [];

    for (const log of logs) {
        const parsed = stakingIface.parseLog(log);
        const stakeType: string = (
            parsed.args.stakeType as string
        ).toLowerCase();
        if (filterAdvancedTypes && !isAdvancedStakeType(stakeType)) {
            continue;
        }

        out.push({
            chain: chainId,
            staker: (parsed.args.account as string).toLowerCase(),
            stakeID: (parsed.args.stakeID as BigNumber).toString(),
            amount: (parsed.args.amount as BigNumber).toString(),
            stakeType,
            stakedAt: log.blockTimestamp,
            lockedTill: (parsed.args.lockedTill as BigNumber).toNumber(),
            blockNumber: log.blockNumber,
            txHash: log.transactionHash,
        });
    }

    console.log(
        `[${chainId}] ${filterAdvancedTypes ? 'advanced' : 'all'} stakes: ${
            out.length
        }`,
    );
    return out;
};

// ---------- Phase 2: Rewards ----------

const collectRewards = async (): Promise<{
    rewards: RewardRecord[];
    commitmentsByLeafId: Map<number, {creationTime: number}>;
}> => {
    const chain = CHAINS.polygon;
    const head = await getHeadBlock(chain);

    const [rewardLogs, commitmentLogs] = await Promise.all([
        getLogsCached(
            chain,
            POLYGON_ARC_ADDRESS,
            TOPICS.RewardGenerated,
            POLYGON_ARC_DEPLOY_BLOCK,
            head,
        ),
        getLogsCached(
            chain,
            POLYGON_PANTHER_POOL_ADDRESS,
            TOPICS.NewCommitments,
            POLYGON_PANTHER_POOL_DEPLOY_BLOCK,
            head,
        ),
    ]);
    console.log(`[polygon] RewardGenerated logs: ${rewardLogs.length}`);
    console.log(`[polygon] NewCommitments logs: ${commitmentLogs.length}`);

    const commitmentsByLeafId = new Map<number, {creationTime: number}>();
    for (const log of commitmentLogs) {
        const parsed = poolIface.parseLog(log);
        const leftLeafId = (parsed.args.leftLeafId as BigNumber).toNumber();
        const creationTime = (parsed.args.creationTime as BigNumber).toNumber();
        commitmentsByLeafId.set(leftLeafId, {creationTime});
    }

    const rewards: RewardRecord[] = [];

    for (const log of rewardLogs) {
        const parsed = arcIface.parseLog(log);
        const leftLeafId = (parsed.args.firstLeafId as BigNumber).toNumber();
        // Prefer NewCommitments.creationTime (deterministic, set on-chain
        // by ARC via safe32TimeNow). Fall back to log block timestamp.
        const fromCommit = commitmentsByLeafId.get(leftLeafId);
        const creationTime = fromCommit
            ? fromCommit.creationTime
            : log.blockTimestamp;
        rewards.push({
            staker: (parsed.args.staker as string).toLowerCase(),
            leftLeafId,
            zkp: (parsed.args.zkp as BigNumber).toString(),
            nft: (parsed.args.nft as BigNumber).toString(),
            blockNumber: log.blockNumber,
            creationTime,
            txHash: log.transactionHash,
        });
    }

    return {rewards, commitmentsByLeafId};
};

// ---------- Phase 3: Exits ----------

const collectExits = async (): Promise<ExitRecord[]> => {
    const chain = CHAINS.polygon;
    const head = await getHeadBlock(chain);

    const nullifierLogs = await getLogsCached(
        chain,
        POLYGON_PANTHER_POOL_ADDRESS,
        TOPICS.Nullifier,
        POLYGON_PANTHER_POOL_DEPLOY_BLOCK,
        head,
    );
    console.log(`[polygon] Nullifier logs: ${nullifierLogs.length}`);

    // Each exit() call emits exactly one Nullifier (verified in contract).
    // The log's blockTimestamp IS the exit time — no extra getBlock call needed.
    // We still need the tx calldata to decode the leafId parameter.
    const txInputs = loadTxCache('polygon');
    const exitsByTxHash = new Map<
        string,
        {leafId: number; blockNumber: number; blockTimestamp: number}
    >();

    let i = 0;
    for (const log of nullifierLogs) {
        i += 1;
        if (i % 25 === 0) {
            console.log(
                `[polygon] decoding exits ${i}/${nullifierLogs.length}`,
            );
            saveTxCache('polygon', txInputs);
        }
        const txHash = log.transactionHash;
        if (exitsByTxHash.has(txHash)) continue;
        const tx = await getTransactionInput(chain, txHash, txInputs);
        if (!tx.data || !tx.data.startsWith(EXIT_SELECTOR)) {
            // Not a direct exit() call — could be a router/multicall. Skip and
            // surface in the report; we expect direct calls in practice.
            continue;
        }
        const decoded = exitIface.decodeFunctionData('exit', tx.data);
        const leafId = (decoded.leafId as BigNumber).toNumber();
        exitsByTxHash.set(txHash, {
            leafId,
            blockNumber: log.blockNumber,
            blockTimestamp: log.blockTimestamp,
        });
    }
    saveTxCache('polygon', txInputs);

    // iTRIAD_SIZE = 4 in TriadIncrementalMerkleTrees: leafId stride per triad
    // is 4 (binary-tree alignment), but only the first 3 positions hold real
    // leaves. Slots: 0=ZKP, 1=NFT, 2=dummy(ZERO_VALUE), 3=non-existent.
    const out: ExitRecord[] = [];
    for (const log of nullifierLogs) {
        const decoded = exitsByTxHash.get(log.transactionHash);
        if (!decoded) continue;
        const slot = decoded.leafId % 4;
        if (slot === 3) {
            console.warn(
                `exit at impossible slot 3 leafId=${decoded.leafId} tx=${log.transactionHash}`,
            );
            continue;
        }
        out.push({
            leafId: decoded.leafId,
            leftLeafId: decoded.leafId - slot,
            slot,
            exitTime: decoded.blockTimestamp,
            blockNumber: decoded.blockNumber,
            txHash: log.transactionHash,
        });
    }
    return out;
};

// ---------- Phase 4: Join + emit ----------

const main = async (): Promise<void> => {
    fs.mkdirSync(OUTPUT_DIR, {recursive: true});

    // Run sequentially: Etherscan's per-key rate limit is global, and parallel
    // collectors caused server-busy errors. Each phase caches independently.
    const ethStakes = await collectStakes('ethereum', true); // V1 advanced only
    const polAllStakes = await collectStakes('polygon', false); // ALL types
    const {rewards} = await collectRewards();
    const exits = await collectExits();

    // ---- Integrity check: leftLeafId uniqueness ----
    const leftLeafCounts = new Map<number, number>();
    for (const r of rewards) {
        leftLeafCounts.set(
            r.leftLeafId,
            (leftLeafCounts.get(r.leftLeafId) ?? 0) + 1,
        );
    }
    const dupLeafIds = [...leftLeafCounts.entries()].filter(([, c]) => c > 1);

    // ---- Index polygon stakes by tx hash for same-tx matching ----
    const polStakeByTx = new Map<string, AdvancedStake>();
    for (const s of polAllStakes) polStakeByTx.set(s.txHash, s);

    // ---- Exits grouped by leftLeafId ----
    const exitsByLeftLeaf = new Map<number, ExitRecord[]>();
    for (const e of exits) {
        const arr = exitsByLeftLeaf.get(e.leftLeafId) ?? [];
        arr.push(e);
        exitsByLeftLeaf.set(e.leftLeafId, arr);
    }

    const defaultExitTime = toIso(todayMidnightUtc());

    // ---- Build per-staker queue of "bridged from mainnet" rewards ----
    // Each polygon RewardGenerated is either polygon-sourced (same-tx StakeCreated)
    // or bridged from mainnet. For mainnet matching we walk in chain order.
    const bridgedRewardsByStaker = new Map<string, RewardRecord[]>();

    // ---- Build output records: one per RewardGenerated ----
    const outputs: OutputStake[] = [];
    const stakeTypesSeen = new Map<string, number>(); // diagnostic
    let polygonSourced = 0;
    let bridgedSourced = 0;

    // Process rewards in chronological order for deterministic per-staker order.
    const sortedRewards = [...rewards].sort(
        (a, b) => a.blockNumber - b.blockNumber,
    );

    for (const r of sortedRewards) {
        const polStake = polStakeByTx.get(r.txHash);
        let sourceChain: 'ethereum' | 'polygon';
        if (polStake) {
            sourceChain = 'polygon';
            polygonSourced += 1;
            stakeTypesSeen.set(
                polStake.stakeType,
                (stakeTypesSeen.get(polStake.stakeType) ?? 0) + 1,
            );
        } else {
            sourceChain = 'ethereum';
            bridgedSourced += 1;
            const arr = bridgedRewardsByStaker.get(r.staker) ?? [];
            arr.push(r);
            bridgedRewardsByStaker.set(r.staker, arr);
        }

        const stakeExits = exitsByLeftLeaf.get(r.leftLeafId) ?? [];
        const zkpExit = stakeExits.find(e => e.slot === 0);
        const nftExit = stakeExits.find(e => e.slot === 1);
        const exitTime = zkpExit ? toIso(zkpExit.exitTime) : defaultExitTime;

        outputs.push({
            staker: r.staker,
            leftLeafId: r.leftLeafId,
            creationTime: toIso(r.creationTime),
            exitTime,
            zkpRewards: r.zkp,
            nftRewards: r.nft,
            zkpExited: !!zkpExit,
            nftExited: !!nftExit,
            zkpExitTime: zkpExit ? toIso(zkpExit.exitTime) : null,
            nftExitTime: nftExit ? toIso(nftExit.exitTime) : null,
            sourceChain,
        });
    }

    // ---- Detect mainnet stakes with no bridged reward (bridge failures) ----
    // For each mainnet StakeCreated, consume one bridged reward for that staker
    // in chronological order. Anything left over is an unmatched mainnet stake.
    const sortedEthStakes = [...ethStakes].sort(
        (a, b) => a.stakedAt - b.stakedAt,
    );
    const bridgeCursor = new Map<string, number>();
    const unmatchedMainnet: AdvancedStake[] = [];
    for (const s of sortedEthStakes) {
        const queue = bridgedRewardsByStaker.get(s.staker) ?? [];
        const idx = bridgeCursor.get(s.staker) ?? 0;
        if (idx >= queue.length) {
            unmatchedMainnet.push(s);
            // Surface as a record with no reward.
            outputs.push({
                staker: s.staker,
                leftLeafId: null,
                creationTime: toIso(s.stakedAt),
                exitTime: defaultExitTime,
                zkpRewards: '0',
                nftRewards: '0',
                zkpExited: false,
                nftExited: false,
                zkpExitTime: null,
                nftExitTime: null,
                sourceChain: 'unmatched-mainnet',
            });
            continue;
        }
        bridgeCursor.set(s.staker, idx + 1);
    }

    // Sort deterministically by leftLeafId (nulls last).
    outputs.sort((a, b) => {
        if (a.leftLeafId === null && b.leftLeafId === null) return 0;
        if (a.leftLeafId === null) return 1;
        if (b.leftLeafId === null) return -1;
        return a.leftLeafId - b.leftLeafId;
    });

    // Bridged rewards that didn't match a mainnet stake (rare; would indicate
    // a missing mainnet StakeCreated — e.g. unknown contract).
    let unconsumedBridged = 0;
    for (const [staker, queue] of bridgedRewardsByStaker) {
        const consumed = bridgeCursor.get(staker) ?? 0;
        unconsumedBridged += queue.length - consumed;
    }

    // Half-exited = stake had BOTH ZKP and NFT rewards but only one side was exited.
    // (User confirmed UI exits both atomically, so this should be rare.)
    const halfExited: number[] = [];
    for (const o of outputs) {
        if (o.leftLeafId === null) continue;
        const hasZkp = BigNumber.from(o.zkpRewards).gt(0);
        const hasNft = BigNumber.from(o.nftRewards).gt(0);
        if (!hasZkp || !hasNft) continue;
        if (o.zkpExited !== o.nftExited) halfExited.push(o.leftLeafId);
    }

    // ---- Write outputs ----
    const stakesJsonPath = path.join(OUTPUT_DIR, 'stakes.json');
    fs.writeFileSync(stakesJsonPath, JSON.stringify(outputs, null, 2));

    const stakeTypesLines = [...stakeTypesSeen.entries()]
        .sort((a, b) => b[1] - a[1])
        .map(([t, c]) => `    ${t}: ${c}`);

    const reportLines = [
        `Advanced Stakes Reconstruction Report`,
        `Generated: ${new Date().toISOString()}`,
        ``,
        `Mainnet advanced StakeCreated (all non-classic): ${ethStakes.length}`,
        `Polygon  StakeCreated (all types):               ${polAllStakes.length}`,
        `Polygon  RewardGenerated events:                 ${rewards.length}`,
        ``,
        `Output records: ${outputs.length}`,
        `  polygon-sourced (same-tx StakeCreated): ${polygonSourced}`,
        `  bridged-from-mainnet:                   ${bridgedSourced}`,
        `  unmatched mainnet (bridge failures):    ${unmatchedMainnet.length}`,
        `Bridged rewards w/o matching mainnet stake (anomaly): ${unconsumedBridged}`,
        `Duplicate leftLeafId in rewards: ${dupLeafIds.length}`,
        ``,
        `Polygon stake types observed (and their reward counts):`,
        ...stakeTypesLines,
        ``,
        `Exit events (total Nullifier emissions): ${exits.length}`,
        `Stakes with ZKP exit:                    ${
            outputs.filter(o => o.zkpExited).length
        }`,
        `Stakes with NFT exit:                    ${
            outputs.filter(o => o.nftExited).length
        }`,
        `Stakes with both exited:                 ${
            outputs.filter(o => o.zkpExited && o.nftExited).length
        }`,
        `Stakes half-exited (zkp xor nft):        ${halfExited.length}`,
        ``,
        unmatchedMainnet.length
            ? `Unmatched mainnet stake details (first 20):`
            : ``,
        ...unmatchedMainnet
            .slice(0, 20)
            .map(
                s =>
                    `  ${s.staker} block=${s.blockNumber} tx=${s.txHash} stakeID=${s.stakeID} amount=${s.amount}`,
            ),
        ``,
        halfExited.length
            ? `Half-exited leftLeafIds (first 20): ${halfExited
                  .slice(0, 20)
                  .join(', ')}`
            : ``,
    ].filter(Boolean);

    const reportPath = path.join(OUTPUT_DIR, 'report.txt');
    fs.writeFileSync(reportPath, reportLines.join('\n'));

    console.log(`\nWrote ${outputs.length} records to ${stakesJsonPath}`);
    console.log(`Report: ${reportPath}\n`);
    console.log(reportLines.join('\n'));
};

main().catch(err => {
    console.error(err);
    process.exit(1);
});
