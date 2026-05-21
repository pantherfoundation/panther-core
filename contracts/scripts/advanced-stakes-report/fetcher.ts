import { providers } from "ethers";
import * as fs from "fs";
import * as path from "path";
import * as https from "https";
import {
    CACHE_DIR,
    ChainConfig,
    ETHERSCAN_KEY,
    ETHERSCAN_V2_URL,
} from "./config";

// Logs are fetched via Etherscan V2 multichain API because the provided Alchemy
// key is on the free tier (10-block eth_getLogs cap, useless at historical scale).
// Single-tx/single-block calls (getTransaction, getBlock) still go through Alchemy
// since they aren't constrained by block range.

export interface RawLog {
    address: string;
    topics: string[];
    data: string;
    blockNumber: number;
    blockTimestamp: number; // unix seconds, provided by Etherscan with each log
    transactionHash: string;
    transactionIndex: number;
    logIndex: number;
}

interface EtherscanLog {
    address: string;
    topics: string[];
    data: string;
    blockNumber: string; // hex
    timeStamp: string; // hex
    gasPrice: string; // hex
    gasUsed: string; // hex
    logIndex: string; // hex
    transactionHash: string;
    transactionIndex: string; // hex
}

interface CacheFile {
    chainId: string;
    address: string;
    topic0: string;
    fromBlock: number;
    toBlock: number;
    logs: RawLog[];
}

const ETHERSCAN_PAGE_LIMIT = 1000;

const sleep = (ms: number): Promise<void> =>
    new Promise((res) => setTimeout(res, ms));

const cacheFilePath = (
    chainId: string,
    address: string,
    topic0: string,
): string => {
    const safeAddr = address.toLowerCase();
    const safeTopic = topic0.toLowerCase();
    return path.join(CACHE_DIR, `${chainId}-${safeAddr}-${safeTopic}.json`);
};

const loadCache = (file: string): CacheFile | null => {
    if (!fs.existsSync(file)) return null;
    try {
        return JSON.parse(fs.readFileSync(file, "utf8")) as CacheFile;
    } catch {
        return null;
    }
};

const saveCache = (file: string, data: CacheFile): void => {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(data));
};

const httpGetJson = (url: string): Promise<unknown> =>
    new Promise((resolve, reject) => {
        https
            .get(url, (res) => {
                const chunks: Buffer[] = [];
                res.on("data", (c) => chunks.push(c));
                res.on("end", () => {
                    const body = Buffer.concat(chunks).toString("utf8");
                    try {
                        resolve(JSON.parse(body));
                    } catch (e) {
                        reject(new Error(`bad JSON: ${body.slice(0, 200)}`));
                    }
                });
            })
            .on("error", reject);
    });

interface EtherscanResponse {
    status: string;
    message: string;
    result: EtherscanLog[] | string;
}

const etherscanGetLogs = async (
    chainId: number,
    address: string,
    topic0: string,
    fromBlock: number,
    toBlock: number,
): Promise<EtherscanLog[]> => {
    const params: Record<string, string> = {
        chainid: String(chainId),
        module: "logs",
        action: "getLogs",
        fromBlock: String(fromBlock),
        toBlock: String(toBlock),
        address,
        topic0,
        page: "1",
        offset: String(ETHERSCAN_PAGE_LIMIT),
        apikey: ETHERSCAN_KEY,
    };
    const qs = Object.keys(params)
        .map((k) => `${k}=${encodeURIComponent(params[k])}`)
        .join("&");
    const url = `${ETHERSCAN_V2_URL}?${qs}`;

    // Retry on transient errors / rate-limits.
    for (let attempt = 0; attempt < 8; attempt += 1) {
        let resp: EtherscanResponse;
        try {
            resp = (await httpGetJson(url)) as EtherscanResponse;
        } catch (e) {
            // Network-level error — retry.
            await sleep(1000 * (attempt + 1));
            continue;
        }
        if (resp.status === "1" && Array.isArray(resp.result)) {
            return resp.result;
        }
        if (resp.status === "0" && resp.message === "No records found") {
            return [];
        }
        const errStr =
            typeof resp.result === "string" ? resp.result : resp.message;
        // Window-too-large signal from Etherscan returns result as string.
        if (/Result window is too large/i.test(errStr || "")) {
            throw new Error("WINDOW_TOO_LARGE");
        }
        // Transient: rate limit, timeout, server-busy. Back off and retry.
        if (
            /rate|timeout|busy|unexpected|temporar|503|504|502/i.test(
                errStr || "",
            )
        ) {
            await sleep(2000 * (attempt + 1));
            continue;
        }
        throw new Error(
            `Etherscan getLogs failed for ${address} ${fromBlock}-${toBlock}: ${errStr}`,
        );
    }
    throw new Error(
        `Etherscan getLogs: too many retries for ${address} ${fromBlock}-${toBlock}`,
    );
};

const toRawLog = (l: EtherscanLog): RawLog => ({
    address: l.address,
    topics: l.topics,
    data: l.data,
    blockNumber: parseInt(l.blockNumber, 16),
    blockTimestamp: parseInt(l.timeStamp, 16),
    transactionHash: l.transactionHash,
    transactionIndex: parseInt(l.transactionIndex, 16),
    logIndex: parseInt(l.logIndex, 16),
});

// Adaptive paginator. Etherscan caps each query at 1000 logs. If we hit the cap
// we must shrink the block range and retry (otherwise we'd silently lose logs).
const fetchRange = async (
    chain: ChainConfig,
    address: string,
    topic0: string,
    fromBlock: number,
    toBlock: number,
): Promise<RawLog[]> => {
    const out: RawLog[] = [];
    let cursor = fromBlock;
    let window = chain.pageBlocks;
    const MIN_WINDOW = 200;
    const MIN_INTER_REQUEST_MS = 220; // ~5 req/sec free-tier limit
    let lastReqAt = 0;

    while (cursor <= toBlock) {
        const end = Math.min(cursor + window - 1, toBlock);
        const sinceLast = Date.now() - lastReqAt;
        if (sinceLast < MIN_INTER_REQUEST_MS) {
            await sleep(MIN_INTER_REQUEST_MS - sinceLast);
        }
        lastReqAt = Date.now();

        let rows: EtherscanLog[];
        try {
            rows = await etherscanGetLogs(
                chain.etherscanChainId,
                address,
                topic0,
                cursor,
                end,
            );
        } catch (err) {
            if (
                (err as Error).message === "WINDOW_TOO_LARGE" &&
                window > MIN_WINDOW
            ) {
                window = Math.max(MIN_WINDOW, Math.floor(window / 2));
                continue;
            }
            throw err;
        }

        if (rows.length === ETHERSCAN_PAGE_LIMIT) {
            // Possible overflow — shrink and retry the same range.
            if (window > MIN_WINDOW) {
                window = Math.max(MIN_WINDOW, Math.floor(window / 2));
                continue;
            }
            // At minimum window we can't shrink further. Surface the issue.
            throw new Error(
                `Etherscan returned ${ETHERSCAN_PAGE_LIMIT} logs at minimum window ` +
                    `${cursor}-${end} for ${address}/${topic0}; cannot guarantee completeness.`,
            );
        }

        out.push(...rows.map(toRawLog));
        cursor = end + 1;
        // Gradually grow back after success.
        if (window < chain.pageBlocks) {
            window = Math.min(chain.pageBlocks, window * 2);
        }
    }
    return out;
};

export const getLogsCached = async (
    chain: ChainConfig,
    address: string,
    topic0: string,
    deployBlock: number,
    headBlock: number,
): Promise<RawLog[]> => {
    const file = cacheFilePath(chain.id, address, topic0);
    const cache = loadCache(file);

    let allLogs: RawLog[] = [];
    let fetchFrom: number;

    if (cache && cache.toBlock >= deployBlock) {
        allLogs = cache.logs;
        fetchFrom = cache.toBlock + 1;
    } else {
        fetchFrom = deployBlock;
    }

    if (fetchFrom > headBlock) return allLogs;

    const fresh = await fetchRange(
        chain,
        address,
        topic0,
        fetchFrom,
        headBlock,
    );
    allLogs = allLogs.concat(fresh);

    saveCache(file, {
        chainId: chain.id,
        address: address.toLowerCase(),
        topic0: topic0.toLowerCase(),
        fromBlock: deployBlock,
        toBlock: headBlock,
        logs: allLogs,
    });

    return allLogs;
};

// --- Block / transaction lookups (use Alchemy RPC — single-call, no range issue) ---

const tsCachePath = (chainId: string): string =>
    path.join(CACHE_DIR, `${chainId}-block-timestamps.json`);

interface TimestampCache {
    [blockNumber: string]: number;
}

const loadTsCache = (chainId: string): TimestampCache => {
    const file = tsCachePath(chainId);
    if (!fs.existsSync(file)) return {};
    try {
        return JSON.parse(fs.readFileSync(file, "utf8")) as TimestampCache;
    } catch {
        return {};
    }
};

const saveTsCache = (chainId: string, cache: TimestampCache): void => {
    const file = tsCachePath(chainId);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(cache));
};

let providerCache: Record<string, providers.JsonRpcProvider> = {};
const getProvider = (chain: ChainConfig): providers.JsonRpcProvider => {
    if (!providerCache[chain.id]) {
        providerCache[chain.id] = new providers.JsonRpcProvider(chain.rpc);
    }
    return providerCache[chain.id];
};

export const getBlockTimestamp = async (
    chain: ChainConfig,
    blockNumber: number,
    cache: TimestampCache,
): Promise<number> => {
    const key = String(blockNumber);
    if (cache[key]) return cache[key];
    const block = await getProvider(chain).getBlock(blockNumber);
    cache[key] = block.timestamp;
    return block.timestamp;
};

export const tsCache = {
    load: loadTsCache,
    save: saveTsCache,
};

export const getHeadBlock = async (chain: ChainConfig): Promise<number> => {
    const tip = await getProvider(chain).getBlockNumber();
    return tip - chain.reorgLag;
};

const txCachePath = (chainId: string): string =>
    path.join(CACHE_DIR, `${chainId}-tx-inputs.json`);

interface TxInputCache {
    [txHash: string]: { data: string; blockNumber: number };
}

export const loadTxCache = (chainId: string): TxInputCache => {
    const file = txCachePath(chainId);
    if (!fs.existsSync(file)) return {};
    try {
        return JSON.parse(fs.readFileSync(file, "utf8")) as TxInputCache;
    } catch {
        return {};
    }
};

export const saveTxCache = (chainId: string, cache: TxInputCache): void => {
    const file = txCachePath(chainId);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(cache));
};

export const getTransactionInput = async (
    chain: ChainConfig,
    txHash: string,
    cache: TxInputCache,
): Promise<{ data: string; blockNumber: number }> => {
    if (cache[txHash]) return cache[txHash];
    const tx = await getProvider(chain).getTransaction(txHash);
    const entry = { data: tx.data, blockNumber: tx.blockNumber ?? 0 };
    cache[txHash] = entry;
    return entry;
};
