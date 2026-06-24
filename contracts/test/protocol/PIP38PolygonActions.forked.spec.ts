// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
//
// PIP-38 — Advanced-staking claim window: Polygon-side unit test.
//
// Runs every Polygon action in the proposal against a forked Polygon
// mainnet at the latest block. Each action is executed as msg.sender =
// polygon multisig (`0x208Fb…`) — the same authority that
// MaticBridgeModule.execTransactionFromModule will invoke in production
// when a bridged message arrives from FxRoot. After each action the test
// asserts the emitted event AND the post-state (storage / view methods).
//
// Writes the captured tx details to `PIP-38-polygon-actions.json` at
// the contracts/ root. The cross-chain proposal generation agent
// (see contracts/tasks/GOVERNANCE.md) wraps each captured action as a
// MaticBridgeModule payload + FxRoot.sendMessageToChild Ethereum tx
// (Mode B).
//
// ─────────────────────────────────────────────────────────────────────
// HOW TO RUN — read the live latest Polygon block, then run:
//
/**
    LATEST_POLYGON=$(curl -s -X POST "$POLYGON_RPC" \
       -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
       | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))")

   HARDHAT_FORKING_URL="https://polygon-mainnet.g.alchemy.com/v2/-bbwqZtH2RJk3xclZ2ccJPa9yik86KQC" \
   HARDHAT_FORKING_ENABLED=1 \
   HARDHAT_CHAIN_ID=137 \
   HARDHAT_FORKING_BLOCK=87765730\
     npx hardhat test test/protocol/PIP38PolygonActions.forked.spec.ts 
 */
// ─────────────────────────────────────────────────────────────────────

import {expect} from 'chai';
import {BigNumber, Contract, ContractTransaction} from 'ethers';
import * as fs from 'fs';
import * as path from 'path';
import {ethers, network} from 'hardhat';

// ===== Constants (mainnet) =====

const POLYGON_MULTISIG = '0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0';
const ADVANCED_STAKE_REWARD_CONTROLLER =
    '0x8f15a43961c27C74CB4F55234A78802401614de3';
const VAULT_PROXY = '0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9';
const ZKP_POLYGON = '0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC';

const MERKLE_ROOT =
    '0x6abb6e25bebc3edb33165f95bae9393996be5b3e83f88c1b4c626b471badaf5e';
const ZERO_BYTES32 =
    '0x0000000000000000000000000000000000000000000000000000000000000000';

// EIP-1967 implementation slot — used to assert the new frozen impl is live.
const EIP1967_IMPL_SLOT =
    '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
const EXPECTED_FROZEN_IMPL = '0x31f63DD9Dd1ba6A4b265A31686139Af7F1cdf923';

const OUTPUT_FILE = path.join(
    __dirname,
    '..',
    '..',
    'PIP-38-polygon-actions.json',
);

// ===== ABIs =====

const arcAbi = [
    'function OWNER() view returns (address)',
    'function rewardParams() view returns (uint32 startTime, uint32 endTime, uint8 startZkpApy, uint8 endZkpApy)',
    'function rescueErc20(address token, address to, uint256 amount) external',
];

const vaultFrozenAbi = [
    'function OWNER() view returns (address)',
    'function root() view returns (bytes32)',
    'function isClaimOpen() view returns (bool)',
    'function claimOpenedAt() view returns (uint256)',
    'function setRoot(bytes32 _root) external',
    'event RootSet(bytes32 root)',
];

const erc20Abi = [
    'function balanceOf(address) view returns (uint256)',
    'event Transfer(address indexed from, address indexed to, uint256 value)',
];

// ===== Output capture =====

interface CapturedAction {
    order: number;
    description: string;
    to: string;
    value: string;
    data: string;
    method: string;
    params: string[];
}

const captured: CapturedAction[] = [];

const capture = (
    order: number,
    description: string,
    populated: {to?: string; data?: string; value?: any},
    method: string,
    params: any[],
): void => {
    if (!populated.to || !populated.data) {
        throw new Error(`populated tx missing to/data for "${description}"`);
    }
    captured.push({
        order,
        description,
        to: populated.to,
        value: populated.value ? populated.value.toString() : '0',
        data: populated.data,
        method,
        params: params.map(p => String(p)),
    });
};

// ===== Helpers =====

const impersonate = async (addr: string) => {
    await network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [addr],
    });
    await network.provider.send('hardhat_setBalance', [
        addr,
        '0x56BC75E2D63100000',
    ]);
    return ethers.provider.getSigner(addr);
};

const findEvent = (
    receipt: {events?: any[]; logs?: any[]},
    iface: Contract['interface'],
    eventName: string,
    address?: string,
) => {
    const logs = receipt.logs || receipt.events || [];
    for (const log of logs) {
        if (address && log.address.toLowerCase() !== address.toLowerCase())
            continue;
        try {
            const parsed = iface.parseLog(log);
            if (parsed.name === eventName) return parsed;
        } catch {
            /* not our event */
        }
    }
    return null;
};

// ===== Tests =====

describe('PIP-38 Phase B — Polygon actions on a forked Polygon mainnet', function () {
    this.timeout(10 * 60 * 1000);

    let arc: Contract;
    let vault: Contract;
    let zkp: Contract;
    let multisig: ReturnType<typeof ethers.provider.getSigner>;

    let blockTimestamp: number;
    let arcZkpDrained: BigNumber;

    before(async () => {
        if (!process.env.HARDHAT_FORKING_ENABLED) {
            throw new Error(
                'This spec requires HARDHAT_FORKING_ENABLED=1 + HARDHAT_FORKING_URL set to a Polygon mainnet RPC.',
            );
        }
        const chainId = (await ethers.provider.getNetwork()).chainId;
        if (chainId !== 137 && chainId !== 31337) {
            throw new Error(
                `expected Polygon (137) or hardhat (31337), got ${chainId}`,
            );
        }

        const latest = await ethers.provider.getBlock('latest');
        blockTimestamp = latest.timestamp;
        console.log(
            `  fork block ${latest.number}  ts ${blockTimestamp} (${new Date(
                blockTimestamp * 1000,
            ).toISOString()})`,
        );

        arc = new ethers.Contract(
            ADVANCED_STAKE_REWARD_CONTROLLER,
            arcAbi,
            ethers.provider,
        );
        vault = new ethers.Contract(
            VAULT_PROXY,
            vaultFrozenAbi,
            ethers.provider,
        );
        zkp = new ethers.Contract(ZKP_POLYGON, erc20Abi, ethers.provider);

        multisig = await impersonate(POLYGON_MULTISIG);
    });

    it('precondition: Vault proxy points to the frozen impl', async () => {
        const slot = await network.provider.send('eth_getStorageAt', [
            VAULT_PROXY,
            EIP1967_IMPL_SLOT,
            'latest',
        ]);
        expect('0x' + slot.slice(-40)).to.equal(
            EXPECTED_FROZEN_IMPL.toLowerCase(),
        );
    });

    it('precondition: ARC.OWNER == polygon multisig', async () => {
        const owner: string = await arc.OWNER();
        expect(owner.toLowerCase()).to.equal(POLYGON_MULTISIG.toLowerCase());
    });

    it('precondition: VaultV0Frozen.OWNER == polygon multisig', async () => {
        const owner: string = await vault.OWNER();
        expect(owner.toLowerCase()).to.equal(POLYGON_MULTISIG.toLowerCase());
    });

    it('precondition: VaultV0Frozen.root() is unset (one-shot setRoot has not run yet)', async () => {
        const root: string = await vault.root();
        expect(root).to.equal(ZERO_BYTES32);
        const open: boolean = await vault.isClaimOpen();
        expect(open).to.equal(false);
    });

    it('precondition: ARC.rewardParams.endTime is in the past (rescueErc20 unlocked)', async () => {
        const rp = await arc.rewardParams();
        expect(rp.endTime).to.be.lessThan(blockTimestamp);
    });

    it('Action 1 — rescueErc20: ZKP moves from ARC to Vault; ERC20 Transfer event present', async () => {
        const arcBalBefore: BigNumber = await zkp.balanceOf(
            ADVANCED_STAKE_REWARD_CONTROLLER,
        );
        const vaultBalBefore: BigNumber = await zkp.balanceOf(VAULT_PROXY);
        expect(arcBalBefore.gt(0)).to.equal(true);
        arcZkpDrained = arcBalBefore;

        const tx1 = await arc.populateTransaction.rescueErc20(
            ZKP_POLYGON,
            VAULT_PROXY,
            arcBalBefore,
        );
        const sent: ContractTransaction = await multisig.sendTransaction(tx1);
        const receipt = await sent.wait();

        const arcBalAfter: BigNumber = await zkp.balanceOf(
            ADVANCED_STAKE_REWARD_CONTROLLER,
        );
        const vaultBalAfter: BigNumber = await zkp.balanceOf(VAULT_PROXY);

        // Balance checks
        expect(arcBalAfter.toString()).to.equal('0');
        expect(vaultBalAfter.sub(vaultBalBefore).toString()).to.equal(
            arcBalBefore.toString(),
        );

        // Event check — ERC20 Transfer from ARC to Vault
        const ev = findEvent(receipt, zkp.interface, 'Transfer', ZKP_POLYGON);
        expect(ev, 'ERC20 Transfer not emitted').to.not.equal(null);
        expect((ev!.args.from as string).toLowerCase()).to.equal(
            ADVANCED_STAKE_REWARD_CONTROLLER.toLowerCase(),
        );
        expect((ev!.args.to as string).toLowerCase()).to.equal(
            VAULT_PROXY.toLowerCase(),
        );
        expect((ev!.args.value as BigNumber).toString()).to.equal(
            arcBalBefore.toString(),
        );

        capture(
            1,
            `Drain the AdvancedStakeRewardController's full ZKP balance into the Vault`,
            tx1,
            'rescueErc20(address,address,uint256)',
            [ZKP_POLYGON, VAULT_PROXY, arcBalBefore.toString()],
        );
    });

    it('Action 2 — setRoot: RootSet event + root storage + isClaimOpen flips true', async () => {
        const tx2 = await vault.populateTransaction.setRoot(MERKLE_ROOT);
        const receipt = await (await multisig.sendTransaction(tx2)).wait();

        // Event check — RootSet on the Vault
        const ev = findEvent(receipt, vault.interface, 'RootSet', VAULT_PROXY);
        expect(ev, 'RootSet not emitted').to.not.equal(null);
        expect((ev!.args.root as string).toLowerCase()).to.equal(
            MERKLE_ROOT.toLowerCase(),
        );

        // View-method state check
        const newRoot: string = await vault.root();
        expect(newRoot.toLowerCase()).to.equal(MERKLE_ROOT.toLowerCase());
        const isOpen: boolean = await vault.isClaimOpen();
        expect(isOpen).to.equal(true);

        // claimOpenedAt should be set to a block timestamp near "now"
        const openedAt: BigNumber = await vault.claimOpenedAt();
        expect(openedAt.gt(0)).to.equal(true);

        capture(
            2,
            `Update the on-chain root on VaultV0Frozen — opens the claim window`,
            tx2,
            'setRoot(bytes32)',
            [MERKLE_ROOT],
        );
    });

    it('post: setRoot is one-shot — a second setRoot from the same owner reverts', async () => {
        await expect(
            vault.connect(multisig).setRoot(MERKLE_ROOT),
        ).to.be.revertedWith('VFrozen: root set');
    });

    after(() => {
        const output = {
            proposalId: 'PIP-38',
            chain: 'polygon',
            chainId: 137,
            executionMode: 'bridge-mode-B',
            executedAs: POLYGON_MULTISIG,
            capturedAt: {
                forkBlockTimestamp: blockTimestamp,
                forkBlockTimestampIso: new Date(
                    blockTimestamp * 1000,
                ).toISOString(),
            },
            notes: [
                'These 2 actions execute on Polygon as msg.sender = polygon multisig (0x208Fb…).',
                'In production, MaticBridgeModule calls 0x208Fb.execTransactionFromModule(action.to, 0, action.data, 0) after a bridged message arrives from FxRoot.',
                'The cross-chain proposal generation agent (per contracts/tasks/GOVERNANCE.md) will wrap each action as: bridgePayload = abi.encode(action.to, 0, action.data, 0, maticBridgeModule.nonce + i); then FxRoot.sendMessageToChild(maticBridgeModule, bridgePayload) as the Ethereum-side tx.',
                'Read MaticBridgeModule.nonce() live at proposal-generation time — do not hardcode.',
            ],
            constants: {
                POLYGON_MULTISIG,
                ADVANCED_STAKE_REWARD_CONTROLLER,
                VAULT_PROXY,
                ZKP_POLYGON,
                MERKLE_ROOT,
                arcZkpDrained: arcZkpDrained
                    ? arcZkpDrained.toString()
                    : '(not captured)',
            },
            actions: captured,
        };
        fs.writeFileSync(OUTPUT_FILE, JSON.stringify(output, null, 2));
        console.log(`\n  Wrote ${captured.length} actions to ${OUTPUT_FILE}\n`);
    });
});
