// Configuration for the advanced-stakes reconstruction script.
//
// Addresses are taken from contracts/deployments/ARCHIVE/production/{mainnet,polygon}.
// All deploy blocks are confirmed against the deployment artifacts; ARC and PantherPoolV0
// only exist on Polygon. RewardGenerated is therefore Polygon-only even for mainnet stakes
// (the STAKE message is bridged via the PoS bridge to the Polygon RewardMaster).

export type ChainId = "ethereum" | "polygon";

export interface ChainConfig {
    id: ChainId;
    // Single-RPC endpoint used for getTransaction / getBlock (no block-range issue).
    rpc: string;
    // Etherscan V2 multichain chainId (1 = ethereum, 137 = polygon).
    etherscanChainId: number;
    // Reorg lag — number of confirmations before we treat the tip as final.
    reorgLag: number;
    // Starting block-range window for Etherscan getLogs.
    // Etherscan returns up to 1000 results per call regardless of range, so this
    // is bounded by event density, not RPC limits. The paginator halves on overflow.
    pageBlocks: number;
    stakingAddress: string;
    stakingDeployBlock: number;
}

export const ALCHEMY_KEY = "-bbwqZtH2RJk3xclZ2ccJPa9yik86KQC";
export const ETHERSCAN_KEY = "5XZJGQTJNTVUT636V6RVM2KF3N1JQWN15H";
export const ETHERSCAN_V2_URL = "https://api.etherscan.io/v2/api";

export const CHAINS: Record<ChainId, ChainConfig> = {
    ethereum: {
        id: "ethereum",
        rpc: `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`,
        etherscanChainId: 1,
        reorgLag: 12,
        pageBlocks: 500_000,
        stakingAddress: "0xf4d06d72dACdD8393FA4eA72FdcC10049711F899",
        // Artifact reports block 10196139 which predates Panther. We pin a safe
        // lower bound and let the paginator skip empty ranges fast.
        stakingDeployBlock: 14_000_000,
    },
    polygon: {
        id: "polygon",
        rpc: `https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`,
        etherscanChainId: 137,
        reorgLag: 50,
        pageBlocks: 500_000,
        stakingAddress: "0x4cEc451F63DBE47D9dA2DeBE2B734E4CB4000Eac",
        stakingDeployBlock: 25_371_523,
    },
};

// Polygon-only contracts that emit reward/exit events.
export const POLYGON_ARC_ADDRESS =
    "0x8f15a43961c27C74CB4F55234A78802401614de3";
export const POLYGON_ARC_DEPLOY_BLOCK = 36_337_906;

export const POLYGON_PANTHER_POOL_ADDRESS =
    "0x9a423671e9Cde99Ae88853B701f98ca9e136877B";
export const POLYGON_PANTHER_POOL_DEPLOY_BLOCK = 36_301_252;

// Stake type discriminators from contracts/staking/actions/Constants.sol.
// The owner can register arbitrary stake types via Staking.addTerms(); we've
// observed extra advanced types on mainnet/polygon (0x466b3169, 0x4454e883)
// that aren't named in the source constants. The robust definition of
// "advanced" is: emits RewardGenerated on Polygon. For mainnet we filter by
// "not classic" instead of an allow-list, so new types are picked up.
export const CLASSIC_STAKE_TYPE = "0x4ab0941a";

export const KNOWN_ADVANCED_STAKE_TYPES: readonly string[] = [
    "0x7ec13a06", // ADVANCED_STAKE_TYPE       (V1)
    "0x8496de05", // ADVANCED_STAKE_V2_TYPE    (V2)
];

// Treat anything that isn't classic as advanced.
export const isAdvancedStakeType = (t: string): boolean =>
    t.toLowerCase() !== CLASSIC_STAKE_TYPE;

// Event signatures and their topic0 (keccak256 of the signature).
// Computed in code at startup; kept here for reference only.
export const EVENT_SIGNATURES = {
    StakeCreated:
        "StakeCreated(address,uint256,uint256,bytes4,uint256)",
    RewardGenerated:
        "RewardGenerated(address,uint256,uint256,uint256)",
    NewCommitments:
        "NewCommitments(uint256,uint256,bytes32[3],bytes)",
    Nullifier: "Nullifier(bytes32)",
} as const;

// exit() function selector on PantherPoolV0.
// Signature: exit(address,uint256,uint64,uint32,uint256,uint256,bytes32[16],bytes32,uint256)
// (TREE_DEPTH + 1 = 16 for the bytes32[] in calldata.)
export const EXIT_FUNCTION_SIGNATURE =
    "exit(address,uint256,uint64,uint32,uint256,uint256,bytes32[16],bytes32,uint256)";

export const CACHE_DIR = `${__dirname}/cache`;
export const OUTPUT_DIR = `${__dirname}/output`;
