// Verify the Vault's PNFT range on Polygon before hardcoding constants.
//
// Checks:
//   1. Vault.NFT.balanceOf == 2000
//   2. ownerOf(0)              -> reverts or != Vault (i.e. id 0 is NOT in range)
//   3. ownerOf(1)              == Vault                (FIRST_NFT_ID lower bound)
//   4. ownerOf(2000)           == Vault                (LAST_NFT_ID upper bound)
//   5. ownerOf(2001)           -> reverts or != Vault (one past last is NOT in range)
//   6. spot-check ~50 random ids in [1, 2000] are owned by Vault
import { providers, utils } from "ethers";
import { CHAINS } from "./config";

const VAULT = "0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9";
const NFT = "0xE5da4955cBC480Eb9Bf9534def229F9D8339eE6d";

const iface = new utils.Interface([
    "function balanceOf(address) view returns (uint256)",
    "function ownerOf(uint256) view returns (address)",
]);

const provider = new providers.JsonRpcProvider(CHAINS.polygon.rpc);

const ownerOf = async (
    id: number,
): Promise<{ ok: boolean; owner?: string; error?: string }> => {
    try {
        const data = iface.encodeFunctionData("ownerOf", [id]);
        const raw = await provider.call({ to: NFT, data });
        const [owner] = iface.decodeFunctionResult("ownerOf", raw);
        return { ok: true, owner: (owner as string).toLowerCase() };
    } catch (e) {
        return { ok: false, error: (e as Error).message.slice(0, 120) };
    }
};

const main = async (): Promise<void> => {
    const vaultLower = VAULT.toLowerCase();

    // balanceOf
    const balRaw = await provider.call({
        to: NFT,
        data: iface.encodeFunctionData("balanceOf", [VAULT]),
    });
    const [bal] = iface.decodeFunctionResult("balanceOf", balRaw);
    console.log(`Vault NFT balance: ${bal.toString()}`);

    // Boundary checks
    const checks: Array<{ id: number; expect: "vault" | "notVault" }> = [
        { id: 0, expect: "notVault" },
        { id: 1, expect: "vault" },
        { id: 2, expect: "vault" },
        { id: 1000, expect: "vault" },
        { id: 1999, expect: "vault" },
        { id: 2000, expect: "vault" },
        { id: 2001, expect: "notVault" },
    ];
    for (const c of checks) {
        const r = await ownerOf(c.id);
        if (!r.ok) {
            // For non-existent ids ERC721 reverts ("ERC721: invalid token ID")
            const pass = c.expect === "notVault";
            console.log(
                `  id=${c.id}: REVERT (${r.error?.split("\n")[0] ?? ""})  ${pass ? "✓" : "✗"}`,
            );
            continue;
        }
        const isVault = r.owner === vaultLower;
        const pass =
            (c.expect === "vault" && isVault) ||
            (c.expect === "notVault" && !isVault);
        console.log(
            `  id=${c.id}: owner=${r.owner}  ${pass ? "✓" : "✗"} (expected ${c.expect})`,
        );
    }

    // Random spot-check
    console.log("\nRandom spot-check of 50 ids in [1, 2000]:");
    const rng = (n: number, seed: number): number =>
        (seed * 9301 + 49297) % 233280 % n;
    const ids = new Set<number>();
    let seed = 12345;
    while (ids.size < 50) {
        seed += 1;
        ids.add(1 + rng(2000, seed));
    }
    let bad = 0;
    for (const id of ids) {
        const r = await ownerOf(id);
        if (!r.ok || r.owner !== vaultLower) {
            console.log(`  id=${id}: ${r.ok ? r.owner : "REVERT"}  ✗`);
            bad += 1;
        }
    }
    if (bad === 0) console.log(`  all 50 owned by Vault ✓`);
    else console.log(`  ${bad}/50 NOT owned by Vault ✗`);
};

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
