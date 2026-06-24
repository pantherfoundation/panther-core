// End-to-end test of the advanced-staking unwind on a forked Polygon
// mainnet. Reads the Merkle data produced by
//   scripts/advanced-stakes-report/build-claim-data.ts
// and exercises the full flow:
//   1. Top up the Vault with ARC's full ZKP balance + the (impersonated)
//      shortfall sourced from VaultV1.
//   2. Owner calls setRoot.
//   3. Each of the 1,235 eligible users claims their ZKP + NFTs.
//   4. Verify Vault ends with 0 ZKP and 0 NFTs.
//
// Run:
//   HARDHAT_FORKING_URL=<polygon-rpc> HARDHAT_FORKING_ENABLED=1 \
//     npx hardhat test test/protocol/VaultV0FrozenClaim.forked.spec.ts
//
// The test impersonates:
//   - 0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0 — Vault + ARC owner (multisig)
//   - 0xDD1fD1a7b4482Dce1287aFFE6Ca8EA128C7a9046 — Polygon V1 Vault (sources
//                                                  the 392,496 ZKP shortfall)
//   - 0x8f15a43961c27C74CB4F55234A78802401614de3 — ARC (sourced ZKP via
//                                                  direct transfer for test
//                                                  simplicity; production
//                                                  uses ARC.rescueErc20)
//   - each of 1,235 claim users in turn.

import {expect} from 'chai';
import {BigNumber, Contract} from 'ethers';
import * as fs from 'fs';
import * as path from 'path';
import {ethers, network} from 'hardhat';

// --- Constants pulled from the chain config ---
const ZKP_TOKEN = '0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC';
const NFT_TOKEN = '0xE5da4955cBC480Eb9Bf9534def229F9D8339eE6d';
const VAULT_PROXY = '0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9';
const ARC = '0x8f15a43961c27C74CB4F55234A78802401614de3';
const VAULT_V1 = '0xDD1fD1a7b4482Dce1287aFFE6Ca8EA128C7a9046'; // shortfall source
const OWNER = '0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0'; // multisig

// Off-chain artifacts produced by build-claim-data.ts.
const CLAIM_DATA_PATH = path.join(
    __dirname,
    '..',
    '..',
    'scripts',
    'advanced-stakes-report',
    'output',
    'claimable-per-user.json',
);
const SUMMARY_PATH = path.join(
    __dirname,
    '..',
    '..',
    'scripts',
    'advanced-stakes-report',
    'output',
    'merkle-summary.json',
);

interface ClaimData {
    root: string;
    userCount: number;
    totalZkpNeededWei: string;
    totalNftNeeded: number;
    users: Array<{
        staker: string;
        totalZkp: string;
        nftCount: number;
        leftLeafIds: number[];
        leaf: string;
        proof: string[];
    }>;
}

const ERC20_ABI = [
    'function balanceOf(address) view returns (uint256)',
    'function transfer(address,uint256) returns (bool)',
];
const ERC721_ABI = [
    'function balanceOf(address) view returns (uint256)',
    'function ownerOf(uint256) view returns (address)',
];
const VAULT_ABI = [
    'function root() view returns (bytes32)',
    'function setRoot(bytes32) external',
    'function claim(uint256 zkpAmount, uint16 nftCount, bool claimNft, bytes32[] proof) external',
    'function claimed(address) view returns (bool)',
    'function nftsClaimed() view returns (uint16)',
    'function FIRST_NFT_ID() view returns (uint16)',
    'function LAST_NFT_ID() view returns (uint16)',
];

const impersonate = async (addr: string) => {
    await network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [addr],
    });
    // Make sure the impersonated address has some MATIC to pay gas.
    await network.provider.send('hardhat_setBalance', [
        addr,
        '0x56BC75E2D63100000', // 100 MATIC
    ]);
    return ethers.provider.getSigner(addr);
};

describe('VaultV0Frozen — full claim flow on forked Polygon', function () {
    this.timeout(5 * 60 * 60 * 1000); // 5 h ceiling — never want a mocha timeout

    let zkp: Contract;
    let nft: Contract;
    let vault: Contract;
    let claimData: ClaimData;

    before(async () => {
        if (!process.env.HARDHAT_FORKING_ENABLED) {
            throw new Error(
                'This test requires HARDHAT_FORKING_ENABLED=1 and HARDHAT_FORKING_URL set to a Polygon RPC.',
            );
        }

        const latest = await ethers.provider.getBlock('latest');
        const chainId = (await ethers.provider.getNetwork()).chainId;
        console.log(
            `  forked at block ${latest.number}  ts ${latest.timestamp} (${new Date(latest.timestamp * 1000).toISOString()})  chainId ${chainId}`,
        );

        claimData = JSON.parse(
            fs.readFileSync(CLAIM_DATA_PATH, 'utf8'),
        ) as ClaimData;
        expect(claimData.users.length).to.equal(claimData.userCount);

        zkp = new ethers.Contract(ZKP_TOKEN, ERC20_ABI, ethers.provider);
        nft = new ethers.Contract(NFT_TOKEN, ERC721_ABI, ethers.provider);
        vault = new ethers.Contract(VAULT_PROXY, VAULT_ABI, ethers.provider);
    });

    it('starts with Vault that exactly matches principal but is short of the gift', async () => {
        const vaultZkp: BigNumber = await zkp.balanceOf(VAULT_PROXY);
        const arcZkp: BigNumber = await zkp.balanceOf(ARC);
        const v1Zkp: BigNumber = await zkp.balanceOf(VAULT_V1);
        const needed = BigNumber.from(claimData.totalZkpNeededWei);
        console.log(`  Vault ZKP:   ${ethers.utils.formatEther(vaultZkp)}`);
        console.log(`  ARC ZKP:     ${ethers.utils.formatEther(arcZkp)}`);
        console.log(`  V1 Vault:    ${ethers.utils.formatEther(v1Zkp)}`);
        console.log(`  Needed:      ${ethers.utils.formatEther(needed)}`);
        const gap = needed.sub(vaultZkp);
        expect(gap.gt(0)).to.eq(true, 'expected ARC+V1 top-up needed');
        expect(gap.lte(arcZkp.add(v1Zkp))).to.eq(
            true,
            'ARC+V1 cannot cover the gap — abort',
        );
    });

    it('Vault NFT inventory is the full 2000 tokens 1..2000', async () => {
        expect((await nft.balanceOf(VAULT_PROXY)).toNumber()).to.equal(2000);
        // Spot checks
        expect((await nft.ownerOf(1)).toLowerCase()).to.equal(
            VAULT_PROXY.toLowerCase(),
        );
        expect((await nft.ownerOf(2000)).toLowerCase()).to.equal(
            VAULT_PROXY.toLowerCase(),
        );
    });

    it('tops up the Vault: ARC ZKP transfer + V1 Vault shortfall', async () => {
        const needed = BigNumber.from(claimData.totalZkpNeededWei);

        // 1) Move ALL of ARC's ZKP into the Vault. In production this is
        // ARC.rescueErc20 (owner-only, gated by rewardParams.endTime).
        // For testing simplicity we impersonate ARC directly and use
        // ERC20.transfer. The net effect on Vault balance is identical.
        const arcSigner = await impersonate(ARC);
        const arcZkpStart: BigNumber = await zkp.balanceOf(ARC);
        await zkp.connect(arcSigner).transfer(VAULT_PROXY, arcZkpStart);
        expect((await zkp.balanceOf(ARC)).toString()).to.equal('0');

        // 2) Top up the rest from V1 Vault.
        const vaultZkpAfterArc: BigNumber = await zkp.balanceOf(VAULT_PROXY);
        const shortfall = needed.sub(vaultZkpAfterArc);
        expect(shortfall.gt(0)).to.eq(true);
        console.log(
            `  Shortfall after ARC top-up: ${ethers.utils.formatEther(shortfall)} ZKP`,
        );
        const v1Signer = await impersonate(VAULT_V1);
        await zkp.connect(v1Signer).transfer(VAULT_PROXY, shortfall);

        // Vault now holds exactly the amount needed.
        const finalBalance: BigNumber = await zkp.balanceOf(VAULT_PROXY);
        expect(finalBalance.toString()).to.equal(needed.toString());
    });

    it('owner sets the Merkle root', async () => {
        // The Vault_Proxy is an EIP-173 (hardhat-deploy) proxy whose fallback
        // always delegates to the implementation regardless of caller. Only
        // the proxy's own admin selectors (upgradeTo / transferOwnership) are
        // intercepted; everything else flows through. The multisig is both
        // the proxy owner AND the VaultV0Frozen.OWNER immutable, so it can
        // call setRoot directly — no proxy-admin shuffle needed.
        const ownerSigner = await impersonate(OWNER);
        await vault.connect(ownerSigner).setRoot(claimData.root);
        expect((await vault.root()).toLowerCase()).to.equal(
            claimData.root.toLowerCase(),
        );
    });

    it('every eligible user can claim exactly their entitlement', async () => {
        const totalUsers = claimData.users.length;
        let processed = 0;
        let sumZkpClaimed = BigNumber.from(0);
        let sumNftClaimed = 0;

        // Per-iteration balance checks dominate the runtime, so we spot-check
        // a sample of users for exact ZKP/NFT increments and rely on the
        // "Vault ends empty" invariant + repeat-claim revert to catch any
        // systematic mismatch in the bulk.
        const sampleIndexes = new Set<number>();
        const step = Math.max(1, Math.floor(totalUsers / 20));
        for (let i = 0; i < totalUsers; i += step) sampleIndexes.add(i);
        sampleIndexes.add(0);
        sampleIndexes.add(totalUsers - 1);

        for (let i = 0; i < totalUsers; i += 1) {
            const u = claimData.users[i];
            const signer = await impersonate(u.staker);

            const checkBalance = sampleIndexes.has(i);
            let zkpBefore = BigNumber.from(0);
            let nftBefore = BigNumber.from(0);
            if (checkBalance) {
                zkpBefore = await zkp.balanceOf(u.staker);
                nftBefore = await nft.balanceOf(u.staker);
            }

            // Pass an explicit gasLimit to skip eth_estimateGas on every call.
            // Largest claim in the dataset is 257 NFTs in one tx; budget
            // generously so no claim ever runs out of gas:
            //   ~200k base + 80k per NFT transferFrom (with safety margin).
            const gasLimit = 200_000 + u.nftCount * 80_000;
            const tx = await vault
                .connect(signer)
                .claim(u.totalZkp, u.nftCount, true, u.proof, {
                    gasLimit,
                });
            await tx.wait();

            if (checkBalance) {
                const zkpAfter: BigNumber = await zkp.balanceOf(u.staker);
                const nftAfter: BigNumber = await nft.balanceOf(u.staker);
                expect(zkpAfter.sub(zkpBefore).toString()).to.equal(
                    u.totalZkp,
                    `ZKP mismatch for ${u.staker} (idx ${i})`,
                );
                expect(nftAfter.sub(nftBefore).toNumber()).to.equal(
                    u.nftCount,
                    `NFT count mismatch for ${u.staker} (idx ${i})`,
                );
            }

            sumZkpClaimed = sumZkpClaimed.add(u.totalZkp);
            sumNftClaimed += u.nftCount;
            processed += 1;
            if (processed % 100 === 0) {
                console.log(
                    `  ${processed}/${totalUsers} claimed (${ethers.utils.formatEther(sumZkpClaimed)} ZKP, ${sumNftClaimed} NFTs)`,
                );
            }
        }
        expect(sumZkpClaimed.toString()).to.equal(
            claimData.totalZkpNeededWei,
        );
        expect(sumNftClaimed).to.equal(claimData.totalNftNeeded);
    });

    it('Vault ends empty (0 ZKP, 0 NFTs)', async () => {
        // Use .toString() everywhere — some ethers v5 paths return
        // plain numbers for uint256 view calls, on which .toNumber() throws.
        const zkpEnd = await zkp.balanceOf(VAULT_PROXY);
        const nftEnd = await nft.balanceOf(VAULT_PROXY);
        const nftsClaimed = await vault.nftsClaimed();
        expect(zkpEnd.toString()).to.equal('0');
        expect(nftEnd.toString()).to.equal('0');
        expect(nftsClaimed.toString()).to.equal('2000');
    });

    it('a second claim from the same user reverts', async () => {
        const first = claimData.users[0];
        const signer = await impersonate(first.staker);
        await expect(
            vault
                .connect(signer)
                .claim(first.totalZkp, first.nftCount, true, first.proof),
        ).to.be.revertedWith('VFrozen: claimed');
    });

    it('a tampered proof reverts', async () => {
        // Pick a fresh address NOT in the tree.
        const fakeAddr = ethers.utils.getAddress(
            '0x000000000000000000000000000000000000beef',
        );
        const fakeSigner = await impersonate(fakeAddr);
        await expect(
            vault
                .connect(fakeSigner)
                .claim(1, 0, false, [ethers.constants.HashZero]),
        ).to.be.revertedWith('VFrozen: bad proof');
    });
});
