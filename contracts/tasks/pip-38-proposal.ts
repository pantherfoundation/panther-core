// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

/**
 * PIP-38 — Wind down the v0 advanced-staking program.
 *
 * Inputs (produced by the fork-sim spec files — see README-pip-38.md):
 *   contracts/PIP-38-ethereum-actions.json   actions 1..6 (direct, on Ethereum)
 *   contracts/PIP-38-polygon-actions.json    actions 7..8 (Polygon, inner calls)
 *
 * Tasks defined here:
 *   pip-38-bridge    — Polygon fork: wrap actions 7..8 in Mode-B bridge
 *                      payloads with consecutive live nonces, simulate them
 *                      end-to-end through MaticBridgeModule, write
 *                      `PIP-38-bridge-messages.json`.
 *   pip-38-ethereum  — No fork: read both JSONs, write `PIP-38-output.txt`
 *                      with two batches (Batch #1 = 6 direct Ethereum actions,
 *                      Batch #2 = 2 FxRoot wrappers).
 *
 *
 * npx hardhat pip-38-bridge
 * npx hardhat pip-38-ethereum
 *
 */

import fs from 'fs';

import {task} from 'hardhat/config';

import {BRIDGE_ADDRESSES} from '../lib/governance/bridgeConstants';

// ===== INPUT / OUTPUT FILES =====

const ETH_ACTIONS_FILE = 'PIP-38-ethereum-actions.json';
const POLY_ACTIONS_FILE = 'PIP-38-polygon-actions.json';
const BRIDGE_MESSAGES_FILE = 'PIP-38-bridge-messages.json';
const OUTPUT_FILE = 'PIP-38-output.txt';

// ===== ABIs =====

const bridgeModuleAbi = [
    'function processMessageFromRoot(uint256 stateId, address rootMessageSender, bytes calldata data)',
    'function nonce() view returns (uint256)',
];

const fxRootIface = [
    'function sendMessageToChild(address receiver, bytes calldata data)',
];

const erc20Abi = ['function balanceOf(address account) view returns (uint256)'];

const vaultFrozenAbi = [
    'function root() view returns (bytes32)',
    'function isClaimOpen() view returns (bool)',
];

// ===== TYPES =====

type Action = {
    order: number;
    description: string;
    to: string;
    value: string;
    data: string;
    method: string;
    params: unknown[];
};

type ActionsFile = {
    proposalId: string;
    chain: string;
    chainId: number;
    executionMode: string;
    executedAs: string;
    constants: Record<string, string | number>;
    actions: Action[];
};

type BridgeMessage = {
    order: number;
    description: string;
    method: string;
    innerTo: string;
    innerData: string;
    bridgeNonce: string;
    encodedPayload: string;
};

const POLYGON_CHAIN_ID = 137;

// ===== POLYGON FORK TASK =====

task(
    'pip-38-bridge',
    'Wrap PIP-38 polygon actions in Mode-B bridge payloads and simulate them through MaticBridgeModule on a Polygon fork',
).setAction(async (_, hre) => {
    const blockNumber = (await hre.ethers.provider.getBlock('latest')).number;
    const chainId = (await hre.ethers.provider.getNetwork()).chainId;
    console.log(
        `\n=== PIP-38 Bridge Simulation (block ${blockNumber}, chainId ${chainId}) ===\n`,
    );

    if (chainId !== POLYGON_CHAIN_ID && chainId !== 31337) {
        console.log(
            `WARNING: chainId=${chainId}, expected 137 (Polygon) or 31337 (Hardhat fork)`,
        );
    }

    if (!fs.existsSync(POLY_ACTIONS_FILE)) {
        throw new Error(
            `${POLY_ACTIONS_FILE} not found. Run the PIP38PolygonActions.forked.spec.ts spec first.`,
        );
    }
    const polyFile: ActionsFile = JSON.parse(
        fs.readFileSync(POLY_ACTIONS_FILE, 'utf-8'),
    );
    console.log(`Loaded ${polyFile.actions.length} polygon actions`);

    const bridgeModule = await hre.ethers.getContractAt(
        bridgeModuleAbi,
        BRIDGE_ADDRESSES.maticBridgeModule,
    );
    const bridgeNonceStart = await bridgeModule.nonce();
    console.log(`MaticBridgeModule.nonce (live):  ${bridgeNonceStart}`);

    // ---- Read pre-state for post-execution assertions ----
    const arcAddr = polyFile.constants
        .ADVANCED_STAKE_REWARD_CONTROLLER as string;
    const vaultAddr = polyFile.constants.VAULT_PROXY as string;
    const zkpPoly = polyFile.constants.ZKP_POLYGON as string;
    const expectedRoot = polyFile.constants.MERKLE_ROOT as string;

    const zkp = await hre.ethers.getContractAt(erc20Abi, zkpPoly);
    const vault = await hre.ethers.getContractAt(vaultFrozenAbi, vaultAddr);

    const beforeArcZkp = await zkp.balanceOf(arcAddr);
    const beforeVaultZkp = await zkp.balanceOf(vaultAddr);
    const beforeRoot = await vault.root();
    console.log(`ASRC ZKP balance BEFORE:        ${beforeArcZkp}`);
    console.log(`Vault ZKP balance BEFORE:       ${beforeVaultZkp}`);
    console.log(`Vault.root BEFORE:              ${beforeRoot}`);

    if (
        beforeRoot !==
        '0x0000000000000000000000000000000000000000000000000000000000000000'
    ) {
        throw new Error(
            `Vault.root is already set (${beforeRoot}). PIP-38 cannot run twice — setRoot is one-shot.`,
        );
    }

    // ---- Impersonate fxChild ----
    await hre.network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [BRIDGE_ADDRESSES.fxChild],
    });
    await hre.network.provider.send('hardhat_setBalance', [
        BRIDGE_ADDRESSES.fxChild,
        '0x3635C9ADC5DEA00000', // 1000 ETH
    ]);
    const fxChildSigner = await hre.ethers.getSigner(BRIDGE_ADDRESSES.fxChild);

    // ---- Build, run, and record each bridge message ----
    const bridgeMessages: BridgeMessage[] = [];

    for (let i = 0; i < polyFile.actions.length; i++) {
        const action = polyFile.actions[i];
        const thisNonce = bridgeNonceStart.add(i);

        const encodedPayload = hre.ethers.utils.defaultAbiCoder.encode(
            ['address', 'uint256', 'bytes', 'uint8', 'uint256'],
            [action.to, 0, action.data, 0, thisNonce],
        );

        console.log(
            `\n[Bridge Msg ${i + 1}/${
                polyFile.actions.length
            }] ${action.description.slice(0, 80)}`,
        );
        console.log(`  inner.to:       ${action.to}`);
        console.log(`  method:         ${action.method}`);
        console.log(`  bridge nonce:   ${thisNonce}`);

        const receipt = await (
            await bridgeModule
                .connect(fxChildSigner)
                .processMessageFromRoot(
                    0,
                    BRIDGE_ADDRESSES.daoMultisig,
                    encodedPayload,
                    {gasLimit: 1_500_000},
                )
        ).wait();
        console.log(`  executed at block ${receipt.blockNumber} ✓`);

        bridgeMessages.push({
            order: action.order,
            description: action.description,
            method: action.method,
            innerTo: action.to,
            innerData: action.data,
            bridgeNonce: thisNonce.toString(),
            encodedPayload,
        });
    }

    // ---- Post-state assertions ----
    const afterArcZkp = await zkp.balanceOf(arcAddr);
    const afterVaultZkp = await zkp.balanceOf(vaultAddr);
    const afterRoot = await vault.root();
    const afterClaimOpen = await vault.isClaimOpen();
    console.log(`\n=== Post-state ===`);
    console.log(`ASRC ZKP balance AFTER:         ${afterArcZkp}`);
    console.log(`Vault ZKP balance AFTER:        ${afterVaultZkp}`);
    console.log(`Vault.root AFTER:               ${afterRoot}`);
    console.log(`Vault.isClaimOpen AFTER:        ${afterClaimOpen}`);

    if (!afterArcZkp.isZero()) {
        throw new Error(
            `ASRC ZKP balance did not drain. Expected 0, got ${afterArcZkp}.`,
        );
    }
    const expectedVaultIncrease = beforeArcZkp;
    const actualVaultIncrease = afterVaultZkp.sub(beforeVaultZkp);
    if (!actualVaultIncrease.eq(expectedVaultIncrease)) {
        throw new Error(
            `Vault ZKP did not receive the drained ASRC balance. Expected +${expectedVaultIncrease}, got +${actualVaultIncrease}.`,
        );
    }
    if (afterRoot.toLowerCase() !== expectedRoot.toLowerCase()) {
        throw new Error(
            `Vault.root mismatch. Expected ${expectedRoot}, got ${afterRoot}.`,
        );
    }
    if (!afterClaimOpen) {
        throw new Error('Vault.isClaimOpen() returned false after setRoot.');
    }
    console.log(`All post-state assertions passed ✓`);

    fs.writeFileSync(
        BRIDGE_MESSAGES_FILE,
        JSON.stringify(bridgeMessages, null, 2),
    );
    console.log(`\nBridge messages saved to ${BRIDGE_MESSAGES_FILE}`);
});

// ===== ETHEREUM CALLDATA GENERATION TASK =====

task(
    'pip-38-ethereum',
    'Combine PIP-38 ethereum-actions.json + bridge-messages.json and write PIP-38-output.txt with two batches',
).setAction(async (_, hre) => {
    console.log('=== Generating PIP-38 Snapshot deliverable ===\n');

    if (!fs.existsSync(ETH_ACTIONS_FILE)) {
        throw new Error(
            `${ETH_ACTIONS_FILE} not found. Run the PIP38EthereumActions.forked.spec.ts spec first.`,
        );
    }
    if (!fs.existsSync(BRIDGE_MESSAGES_FILE)) {
        throw new Error(
            `${BRIDGE_MESSAGES_FILE} not found. Run 'npx hardhat pip-38-bridge' on a Polygon fork first.`,
        );
    }

    const ethFile: ActionsFile = JSON.parse(
        fs.readFileSync(ETH_ACTIONS_FILE, 'utf-8'),
    );
    const bridgeMessages: BridgeMessage[] = JSON.parse(
        fs.readFileSync(BRIDGE_MESSAGES_FILE, 'utf-8'),
    );

    console.log(`Loaded ${ethFile.actions.length} ethereum direct actions`);
    console.log(`Loaded ${bridgeMessages.length} bridge messages`);

    // ---- Wrap each bridge message in FxRoot.sendMessageToChild ----
    const fxRoot = await hre.ethers.getContractAt(
        fxRootIface,
        BRIDGE_ADDRESSES.fxRoot,
    );

    const ethereumDirect = ethFile.actions.map(a => ({
        order: a.order,
        description: a.description,
        to: a.to,
        value: a.value,
        data: a.data,
        method: a.method,
        params: a.params,
    }));

    const bridgeWrapped = await Promise.all(
        bridgeMessages.map(async (msg, idx) => {
            const calldata =
                await fxRoot.populateTransaction.sendMessageToChild(
                    BRIDGE_ADDRESSES.maticBridgeModule,
                    msg.encodedPayload,
                );
            return {
                order: ethereumDirect.length + idx + 1, // continue numbering 7, 8
                description: msg.description,
                to: BRIDGE_ADDRESSES.fxRoot,
                value: '0',
                data: calldata.data as string,
                method: 'sendMessageToChild(address,bytes)',
                params: [
                    BRIDGE_ADDRESSES.maticBridgeModule,
                    msg.encodedPayload,
                ],
                bridgeNonce: msg.bridgeNonce,
                innerCall: {to: msg.innerTo, method: msg.method},
            };
        }),
    );

    // ---- Build the human-readable + dual-batch deliverable ----
    const lines: string[] = [];
    lines.push(
        '** PIP-38: Wind down v0 advanced staking — release vesting, drain controller, open claim window **',
    );
    lines.push('');
    lines.push('** Addresses **');
    lines.push('');
    lines.push('Panther / bridge contracts on Ethereum:');
    lines.push(`    - DAO_Multisig@eth: ${BRIDGE_ADDRESSES.daoMultisig}`);
    lines.push(`    - FxRoot@eth: ${BRIDGE_ADDRESSES.fxRoot}`);
    lines.push(`    - VestingPools@eth: ${ethFile.constants.VESTING_POOLS}`);
    lines.push(`    - ZKP@eth: ${ethFile.constants.ZKP}`);
    lines.push(
        `    - ERC20Predicate@eth: ${ethFile.constants.ERC20_PREDICATE}`,
    );
    lines.push(
        `    - RootChainManager@eth: ${ethFile.constants.ROOT_CHAIN_MANAGER}`,
    );
    lines.push(
        `    - Base deployer wallet@eth: ${ethFile.constants.BASE_DEPLOYER_WALLET}`,
    );
    lines.push('');
    lines.push('Panther contracts on Polygon:');
    lines.push(
        `    - polygonMultisig@matic: ${BRIDGE_ADDRESSES.polygonMultisig}`,
    );
    lines.push(
        `    - MaticBridgeModule@matic: ${BRIDGE_ADDRESSES.maticBridgeModule}`,
    );
    lines.push(
        `    - VaultV0Frozen proxy@matic: ${
            ethFile.constants.VAULT_POLYGON as string
        }`,
    );
    lines.push(
        `    - AdvancedStakeRewardController@matic: 0x8f15a43961c27C74CB4F55234A78802401614de3`,
    );
    lines.push(
        `    - ZKP (pZKP)@matic: 0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC`,
    );
    lines.push('');
    lines.push('** Transactions for the Snapshot **');
    lines.push('');
    lines.push('Transactions Overview');
    lines.push(
        '   # Wind down the v0 advanced-staking program: (1) create a vesting pool funding 5,492,496.05 ZKP, (2) move its start into the past so the entire allocation is releasable, (3-4) release the two splits, (5-6) approve + bridge the 392,496.05 ZKP shortfall to the Polygon Vault via the Polygon PoS bridge, (7) drain the AdvancedStakeRewardController balance into the Vault on Polygon (Mode-B bridge), (8) set the Merkle root on VaultV0Frozen to open the claim window (Mode-B bridge). All 8 transactions are signed by the Ethereum DAO Multisig.',
    );
    let n = 1;
    for (const a of ethereumDirect) {
        lines.push(
            `    ${n}. ${a.method.split('(')[0]} on ${shortAddr(
                a.to,
            )} // ${a.description.slice(0, 100)}`,
        );
        n++;
    }
    for (const w of bridgeWrapped) {
        lines.push(
            `    ${n}. FxRoot@eth::sendMessageToChild(MaticBridgeModule, encodedPayload) // bridge ${
                w.innerCall.method.split('(')[0]
            } on ${shortAddr(w.innerCall.to)} (${w.description.slice(0, 80)})`,
        );
        n++;
    }
    lines.push('');

    // ---- Tx-detail batches first (both), then JSON batches (both) ----

    // Batch #1 details — Ethereum direct actions
    lines.push('** Batch #1 — Ethereum direct actions (6 transactions) **');
    lines.push('========');
    for (const a of ethereumDirect) {
        lines.push('');
        lines.push(`    Tx #${a.order}: ${a.description}`);
        lines.push('        To:');
        lines.push(
            `            ${a.to} // ${labelEthereumTarget(
                a.to,
                ethFile.constants,
            )}`,
        );
        lines.push('        Value:');
        lines.push(`            ${a.value}`);
        lines.push('        Data:');
        lines.push(`            ${a.data}`);
        lines.push('        Method:');
        lines.push(`            ${a.method}`);
    }
    lines.push('');
    lines.push('');

    // Batch #2 details — Polygon bridge wrappers (still signed on Ethereum)
    lines.push(
        '** Batch #2 — Polygon bridge wrappers (2 transactions, signed on Ethereum) **',
    );
    lines.push('========');
    for (const w of bridgeWrapped) {
        lines.push('');
        lines.push(`    Tx #${w.order}: ${w.description}`);
        lines.push('        To:');
        lines.push(`            ${w.to} // FxRoot@eth`);
        lines.push('        Value:');
        lines.push(`            ${w.value}`);
        lines.push('        Data:');
        lines.push(`            ${w.data}`);
        lines.push('        Method:');
        lines.push(`            ${w.method}`);
        lines.push('        Inner (Polygon-side):');
        lines.push(`            target: ${w.innerCall.to}`);
        lines.push(`            method: ${w.innerCall.method}`);
        lines.push(`            bridge nonce: ${w.bridgeNonce}`);
    }
    lines.push('');
    lines.push('');

    // Batch #1 JSON — for Gnosis Safe Transaction Builder
    lines.push('** Batch #1 — JSON for Gnosis Safe Transaction Builder **');
    lines.push('========');
    lines.push('');
    lines.push('    [');
    for (let i = 0; i < ethereumDirect.length; i++) {
        const a = ethereumDirect[i];
        const trailing = i === ethereumDirect.length - 1 ? '' : ',';
        lines.push('        {');
        lines.push(
            `            "to": "${a.to}", // ${labelEthereumTarget(
                a.to,
                ethFile.constants,
            )}`,
        );
        lines.push(`            "operation": "0",`);
        lines.push(`            "value": "0.0",`);
        lines.push(`            "data": "${a.data}",`);
        lines.push(`            "method": "${a.method}",`);
        lines.push(`            "params": ${JSON.stringify(a.params)}`);
        lines.push(`        }${trailing}`);
    }
    lines.push('    ]');
    lines.push('');

    // Batch #2 JSON — for Gnosis Safe Transaction Builder
    lines.push('** Batch #2 — JSON for Gnosis Safe Transaction Builder **');
    lines.push('========');
    lines.push('');
    lines.push('    [');
    for (let i = 0; i < bridgeWrapped.length; i++) {
        const w = bridgeWrapped[i];
        const trailing = i === bridgeWrapped.length - 1 ? '' : ',';
        lines.push('        {');
        lines.push(`            "to": "${w.to}", // FxRoot@eth`);
        lines.push(`            "operation": "0",`);
        lines.push(`            "value": "0.0",`);
        lines.push(`            "data": "${w.data}",`);
        lines.push(`            "method": "${w.method}",`);
        lines.push(`            "params": [`);
        lines.push(`                "${(w.params as string[])[0]}",`);
        lines.push(`                "${(w.params as string[])[1]}"`);
        lines.push(`            ]`);
        lines.push(`        }${trailing}`);
    }
    lines.push('    ]');
    lines.push('');

    fs.writeFileSync(OUTPUT_FILE, lines.join('\n'));

    console.log(`Saved: ${OUTPUT_FILE}`);
    console.log(`  Batch #1: ${ethereumDirect.length} direct Ethereum txs`);
    console.log(`  Batch #2: ${bridgeWrapped.length} FxRoot bridge wrappers`);
});

function shortAddr(a: string): string {
    return `${a.slice(0, 6)}…${a.slice(-4)}`;
}

function labelEthereumTarget(
    addr: string,
    constants: Record<string, string | number>,
): string {
    const map: Record<string, string> = {
        [(constants.VESTING_POOLS as string).toLowerCase()]: 'VestingPools@eth',
        [(constants.ZKP as string).toLowerCase()]: 'ZKP@eth',
        [(constants.ROOT_CHAIN_MANAGER as string).toLowerCase()]:
            'RootChainManager@eth',
    };
    return map[addr.toLowerCase()] ?? addr;
}

// Exposed for the test-ethereum task to share the file constants.
export const PIP_38_FILES = {
    eth: ETH_ACTIONS_FILE,
    bridgeMessages: BRIDGE_MESSAGES_FILE,
    output: OUTPUT_FILE,
};
