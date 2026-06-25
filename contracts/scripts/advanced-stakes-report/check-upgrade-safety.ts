// Print storage layout for VaultV0 (old impl) and VaultV0Frozen (new impl),
// then read on-chain `terms(stakeType)` for every known advanced stake type
// on both chains so we can decide whether `disableTerms` is still needed.
//
// Run:
//   npx hardhat run scripts/advanced-stakes-report/check-upgrade-safety.ts

import hre from "hardhat";
import { providers, utils } from "ethers";

interface StorageVar {
    slot: string;
    offset: number;
    label: string;
    type: string;
}

const printLayout = async (
    fqName: string,
    file: string,
    contract: string,
): Promise<void> => {
    const info = await hre.artifacts.getBuildInfo(fqName);
    if (!info) {
        console.log(`(no build info for ${fqName})`);
        return;
    }
    const layout =
        info.output.contracts[file]?.[contract]?.["storageLayout"];
    console.log(`\n=== ${contract} ===`);
    if (!layout || !layout.storage || layout.storage.length === 0) {
        console.log("  (no storage variables)");
        return;
    }
    for (const v of layout.storage as StorageVar[]) {
        console.log(
            `  slot ${v.slot.padStart(2)} offset ${String(v.offset).padStart(2)}  ${v.label.padEnd(20)}  ${v.type}`,
        );
    }
};

const POLY_RPC = `https://polygon-mainnet.g.alchemy.com/v2/-bbwqZtH2RJk3xclZ2ccJPa9yik86KQC`;
const ETH_RPC = `https://eth-mainnet.g.alchemy.com/v2/-bbwqZtH2RJk3xclZ2ccJPa9yik86KQC`;
const POL_STAKING = "0x4cEc451F63DBE47D9dA2DeBE2B734E4CB4000Eac";
const ETH_STAKING = "0xf4d06d72dACdD8393FA4eA72FdcC10049711F899";

const TERMS_IFACE = new utils.Interface([
    // Exact order from contracts/staking/interfaces/IStakingTypes.sol:
    // isEnabled, isRewarded, minAmountScaled, maxAmountScaled,
    // allowedSince, allowedTill, lockedTill, exactLockPeriod, minLockPeriod
    "function terms(bytes4) view returns (bool isEnabled, bool isRewarded, uint32 minAmountScaled, uint32 maxAmountScaled, uint32 allowedSince, uint32 allowedTill, uint32 lockedTill, uint32 exactLockPeriod, uint32 minLockPeriod)",
]);

const POL_TYPES = ["0x7ec13a06", "0x8496de05", "0x466b3169", "0x4454e883"];
const ETH_TYPES = [
    "0x7ec13a06",
    "0x8496de05",
    "0x466b3169",
    "0x4454e883",
    "0xf51d0a02",
];

const readTerms = async (
    rpc: string,
    contract: string,
    types: readonly string[],
    label: string,
): Promise<void> => {
    const p = new providers.JsonRpcProvider(rpc);
    const now = Math.floor(Date.now() / 1000);
    console.log(`\n=== ${label} Staking ${contract} (now=${now}) ===`);
    for (const t of types) {
        try {
            const data = TERMS_IFACE.encodeFunctionData("terms", [t]);
            const raw = await p.call({ to: contract, data });
            const r = TERMS_IFACE.decodeFunctionResult("terms", raw);
            const isEnabled = r.isEnabled as boolean;
            const isRewarded = r.isRewarded as boolean;
            const allowedTill = Number(r.allowedTill);
            const expired = allowedTill !== 0 && allowedTill < now;
            const blocked = !isEnabled || expired;
            const expiryStr =
                allowedTill === 0
                    ? "never"
                    : new Date(allowedTill * 1000).toISOString();
            console.log(
                `  ${t}: isEnabled=${isEnabled} isRewarded=${isRewarded}  allowedTill=${expiryStr}  -> ${blocked ? "BLOCKED" : "ACCEPTS NEW STAKES"}`,
            );
        } catch (e) {
            console.log(`  ${t}: read failed (${(e as Error).message.slice(0, 80)})`);
        }
    }
};

const main = async (): Promise<void> => {
    console.log("--- Storage layouts ---");
    await printLayout(
        "contracts/protocol/v0/VaultV0.sol:VaultV0",
        "contracts/protocol/v0/VaultV0.sol",
        "VaultV0",
    );
    await printLayout(
        "contracts/protocol/v0/VaultV0Frozen.sol:VaultV0Frozen",
        "contracts/protocol/v0/VaultV0Frozen.sol",
        "VaultV0Frozen",
    );

    console.log("\n--- Stake terms on-chain ---");
    await readTerms(POLY_RPC, POL_STAKING, POL_TYPES, "Polygon");
    await readTerms(ETH_RPC, ETH_STAKING, ETH_TYPES, "Mainnet");
};

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
