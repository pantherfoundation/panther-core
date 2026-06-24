// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

/**
 * PIP-38 — Ethereum-side fork verifier.
 *
 * Replays every Ethereum transaction in `PIP-38-output.txt`:
 *   1..6  direct actions   (from PIP-38-ethereum-actions.json)
 *   7..8  FxRoot wrappers  (from PIP-38-bridge-messages.json)
 *
 * After each tx, asserts the same storage + event invariants the spec
 * `test/protocol/PIP38EthereumActions.forked.spec.ts` checks at generation
 * time. Before sending, fast-forwards the fork clock into the captured
 * `[startPast + 1d, startFuture]` window so the pool timestamps in the
 * calldata remain valid (mirrors the spec's DAO_EXECUTION_DELAY_SECS).
 *
 * Usage:
    HARDHAT_FORKING_URL='https://eth-mainnet.g.alchemy.com/v2/<KEY>' \
    HARDHAT_FORKING_ENABLED=true \
    HARDHAT_FORKING_BLOCK=<LATEST_ETH_BLOCK> \
    npx hardhat pip-38-test-ethereum
 */

import fs from 'fs';

import {BigNumber} from 'ethers';
import {task} from 'hardhat/config';

import {BRIDGE_ADDRESSES} from '../lib/governance/bridgeConstants';
import {PIP_38_FILES} from './pip-38-proposal';

const POOL_VESTING_DAYS_DEFAULT = 1;
const ONE_DAY = 24 * 60 * 60;
const EXECUTION_DELAY_DAYS = 4; // match spec's DAO_EXECUTION_DELAY_SECS

const vestingPoolsAbi = [
    'function owner() view returns (address)',
    'function getPool(uint256 poolId) view returns (tuple(bool isPreMinted, bool isAdjustable, uint32 start, uint16 vestingDays, uint48 sAllocation, uint48 sUnlocked, uint96 vested))',
    'function getWallet(uint256 poolId) view returns (address)',
    'function totalAllocation() view returns (uint96)',
    'function releasableAmount(uint256 poolId) view returns (uint256)',
    'event PoolAdded(uint256 indexed poolId, address indexed wallet, uint256 allocation)',
    'event PoolUpdated(uint256 indexed poolId, uint256 start, uint256 vestingDays)',
    'event Released(uint256 indexed poolId, address to, uint256 amount)',
];

const erc20Abi = [
    'function balanceOf(address) view returns (uint256)',
    'function allowance(address owner, address spender) view returns (uint256)',
    'event Approval(address indexed owner, address indexed spender, uint256 value)',
    'event Transfer(address indexed from, address indexed to, uint256 value)',
];

const erc20PredicateAbi = [
    'event LockedERC20(address indexed depositor, address indexed depositReceiver, address indexed rootToken, uint256 amount)',
];

const fxRootIfaceAbi = [
    'function sendMessageToChild(address receiver, bytes calldata data)',
];

task(
    'pip-38-test-ethereum',
    'Replay PIP-38 Ethereum txs (6 direct + 2 FxRoot wrappers) on a forked Ethereum mainnet with full storage + event assertions',
).setAction(async (_, hre) => {
    if (!process.env.HARDHAT_FORKING_BLOCK) {
        console.log('WARNING: HARDHAT_FORKING_BLOCK is not set.');
    }

    const blockNumber = (await hre.ethers.provider.getBlock('latest')).number;
    const chainId = (await hre.ethers.provider.getNetwork()).chainId;
    console.log(`\n=== PIP-38 Ethereum TX Test ===`);
    console.log(`Forked block: ${blockNumber} (chainId: ${chainId})\n`);

    if (chainId !== 1 && chainId !== 31337) {
        console.log(
            `WARNING: chainId=${chainId}, expected 1 (Ethereum) or 31337 (Hardhat fork)`,
        );
    }

    if (!fs.existsSync(PIP_38_FILES.eth)) {
        throw new Error(
            `${PIP_38_FILES.eth} not found. Run the PIP38EthereumActions.forked.spec.ts spec first.`,
        );
    }
    if (!fs.existsSync(PIP_38_FILES.bridgeMessages)) {
        throw new Error(
            `${PIP_38_FILES.bridgeMessages} not found. Run 'npx hardhat pip-38-bridge' on a Polygon fork first.`,
        );
    }

    const ethFile = JSON.parse(fs.readFileSync(PIP_38_FILES.eth, 'utf-8'));
    const bridgeMessages = JSON.parse(
        fs.readFileSync(PIP_38_FILES.bridgeMessages, 'utf-8'),
    );
    console.log(
        `Loaded ${ethFile.actions.length} direct actions + ${bridgeMessages.length} bridge wrappers\n`,
    );

    const c = ethFile.constants as Record<string, string | number>;
    const DAO_MULTISIG = c.DAO_MULTISIG as string;
    const VESTING_POOLS = c.VESTING_POOLS as string;
    const ZKP = c.ZKP as string;
    const ERC20_PREDICATE = c.ERC20_PREDICATE as string;
    const VAULT_POLYGON = c.VAULT_POLYGON as string;
    const BASE_DEPLOYER_WALLET = c.BASE_DEPLOYER_WALLET as string;
    const SHORTFALL_ZKP_WEI = BigNumber.from(c.SHORTFALL_ZKP_WEI);
    const BASE_AMOUNT_WEI = BigNumber.from(c.BASE_AMOUNT_WEI);
    const POOL_S_ALLOCATION = BigNumber.from(c.POOL_S_ALLOCATION);
    const POOL_AMOUNT_WEI = BigNumber.from(c.POOL_AMOUNT_WEI);
    const POOL_VESTING_DAYS = Number(
        c.POOL_VESTING_DAYS ?? POOL_VESTING_DAYS_DEFAULT,
    );
    const newPoolId = Number(c.newPoolId);
    const startFuture = Number(c.startFuture);
    const startPast = Number(c.startPast);

    // ---- Verify FxRoot has code ----
    const fxRootCode = await hre.ethers.provider.getCode(
        BRIDGE_ADDRESSES.fxRoot,
    );
    if (fxRootCode === '0x') {
        throw new Error(
            `FxRoot at ${BRIDGE_ADDRESSES.fxRoot} has no code. Are you forking Ethereum mainnet?`,
        );
    }

    // ---- Fast-forward chain into the captured calldata's valid window ----
    // updatePoolTime requires _timeNow() > startPast + vestingDays*1d
    // addVestingPools requires startFuture >= block.timestamp
    const minValidTs = startPast + POOL_VESTING_DAYS * ONE_DAY + 1;
    const maxValidTs = startFuture;
    const targetTs = startPast + EXECUTION_DELAY_DAYS * ONE_DAY;
    const currentBlock = await hre.ethers.provider.getBlock('latest');

    console.log(`Valid calldata window: [${minValidTs}, ${maxValidTs}]`);
    console.log(
        `Captured startPast:    ${startPast} (${new Date(
            startPast * 1000,
        ).toISOString()})`,
    );
    console.log(
        `Captured startFuture:  ${startFuture} (${new Date(
            startFuture * 1000,
        ).toISOString()})`,
    );
    console.log(
        `Current chain time:    ${currentBlock.timestamp} (${new Date(
            currentBlock.timestamp * 1000,
        ).toISOString()})`,
    );

    if (currentBlock.timestamp >= maxValidTs) {
        throw new Error(
            `Chain timestamp (${currentBlock.timestamp}) is already past startFuture (${maxValidTs}). The captured PIP-38-ethereum-actions.json is stale — re-run the spec to refresh.`,
        );
    }

    if (currentBlock.timestamp < targetTs) {
        await hre.network.provider.send('evm_setNextBlockTimestamp', [
            targetTs,
        ]);
        await hre.network.provider.send('evm_mine', []);
        const advanced = await hre.ethers.provider.getBlock('latest');
        console.log(
            `Advanced chain to ${advanced.timestamp} (${new Date(
                advanced.timestamp * 1000,
            ).toISOString()})  — +${EXECUTION_DELAY_DAYS}d from startPast\n`,
        );
    } else {
        console.log(`Chain already past targetTs; no fast-forward needed\n`);
    }

    // ---- Impersonate DAO Multisig ----
    await hre.network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [DAO_MULTISIG],
    });
    await hre.network.provider.send('hardhat_setBalance', [
        DAO_MULTISIG,
        '0x56BC75E2D63100000', // 100 ETH
    ]);
    const daoSigner = await hre.ethers.getSigner(DAO_MULTISIG);
    console.log(`Impersonated DAO Multisig: ${DAO_MULTISIG}\n`);

    const vp = new hre.ethers.Contract(
        VESTING_POOLS,
        vestingPoolsAbi,
        hre.ethers.provider,
    );
    const zkp = new hre.ethers.Contract(ZKP, erc20Abi, hre.ethers.provider);
    const predicateIface = new hre.ethers.utils.Interface(erc20PredicateAbi);
    const fxRootIface = new hre.ethers.utils.Interface(fxRootIfaceAbi);

    // ---- Preconditions ----
    const ownerLive: string = await vp.owner();
    if (ownerLive.toLowerCase() !== DAO_MULTISIG.toLowerCase()) {
        throw new Error(
            `VestingPools.owner is ${ownerLive}, expected ${DAO_MULTISIG}`,
        );
    }
    console.log(`Precondition: VestingPools.owner == DAO_MULTISIG ✓`);

    let getPoolReverted = false;
    try {
        await vp.getPool(newPoolId);
    } catch {
        getPoolReverted = true;
    }
    if (!getPoolReverted) {
        throw new Error(
            `getPool(${newPoolId}) did NOT revert — a pool with that id already exists on Ethereum. Bump newPoolId in the spec and re-run.`,
        );
    }
    console.log(
        `Precondition: getPool(${newPoolId}) reverts (pool not yet created) ✓\n`,
    );

    // ===================================================================
    // Direct actions 1..6 — same assertions as the spec
    // ===================================================================
    const [action1, action2, action3, action4, action5, action6] =
        ethFile.actions;

    // ---- Action 1: addVestingPools ----
    await runDirect(
        '1',
        action1.description,
        action1.to,
        action1.data,
        async (receipt: any) => {
            const ev = findEvent(
                receipt,
                vp.interface,
                'PoolAdded',
                VESTING_POOLS,
            );
            if (!ev) throw new Error('PoolAdded not emitted');
            if ((ev.args.poolId as BigNumber).toNumber() !== newPoolId)
                throw new Error(`PoolAdded.poolId mismatch: ${ev.args.poolId}`);
            if (
                (ev.args.wallet as string).toLowerCase() !==
                DAO_MULTISIG.toLowerCase()
            )
                throw new Error(`PoolAdded.wallet mismatch: ${ev.args.wallet}`);
            if (!(ev.args.allocation as BigNumber).eq(POOL_AMOUNT_WEI))
                throw new Error(
                    `PoolAdded.allocation mismatch: ${ev.args.allocation}`,
                );

            const pool = await vp.getPool(newPoolId);
            if (pool.isPreMinted !== false)
                throw new Error('pool.isPreMinted != false');
            if (pool.isAdjustable !== true)
                throw new Error('pool.isAdjustable != true');
            if (pool.start !== startFuture)
                throw new Error(
                    `pool.start ${pool.start} != startFuture ${startFuture}`,
                );
            if (pool.vestingDays !== POOL_VESTING_DAYS)
                throw new Error(`pool.vestingDays != ${POOL_VESTING_DAYS}`);
            if (!BigNumber.from(pool.sAllocation).eq(POOL_S_ALLOCATION))
                throw new Error('pool.sAllocation mismatch');
            if (!BigNumber.from(pool.sUnlocked).eq(POOL_S_ALLOCATION))
                throw new Error('pool.sUnlocked mismatch');
            if (!BigNumber.from(pool.vested).eq(0))
                throw new Error('pool.vested != 0');

            const wallet: string = await vp.getWallet(newPoolId);
            if (wallet.toLowerCase() !== DAO_MULTISIG.toLowerCase())
                throw new Error(`getWallet mismatch: ${wallet}`);
            console.log(
                `    pool.start=${pool.start}  sAllocation=${pool.sAllocation}  wallet=${wallet}`,
            );
        },
    );

    // ---- Action 2: updatePoolTime ----
    await runDirect(
        '2',
        action2.description,
        action2.to,
        action2.data,
        async (receipt: any) => {
            const ev = findEvent(
                receipt,
                vp.interface,
                'PoolUpdated',
                VESTING_POOLS,
            );
            if (!ev) throw new Error('PoolUpdated not emitted');
            if ((ev.args.poolId as BigNumber).toNumber() !== newPoolId)
                throw new Error('PoolUpdated.poolId mismatch');
            if ((ev.args.start as BigNumber).toNumber() !== startPast)
                throw new Error(
                    `PoolUpdated.start ${ev.args.start} != startPast ${startPast}`,
                );

            const pool = await vp.getPool(newPoolId);
            if (pool.start !== startPast)
                throw new Error(
                    `pool.start ${pool.start} != startPast ${startPast}`,
                );

            const releasable: BigNumber = await vp.releasableAmount(newPoolId);
            if (!releasable.gte(POOL_AMOUNT_WEI))
                throw new Error(
                    `releasable (${releasable}) < POOL_AMOUNT_WEI (${POOL_AMOUNT_WEI})`,
                );
            console.log(
                `    pool.start=${
                    pool.start
                }  releasable=${releasable.toString()}`,
            );
        },
    );

    // ---- Action 3: releaseTo DAO ----
    await runDirect(
        '3',
        action3.description,
        action3.to,
        action3.data,
        async (receipt: any, before: any) => {
            const ev = findEvent(
                receipt,
                vp.interface,
                'Released',
                VESTING_POOLS,
            );
            if (!ev) throw new Error('Released (DAO) not emitted');
            if ((ev.args.poolId as BigNumber).toNumber() !== newPoolId)
                throw new Error('Released.poolId mismatch');
            if (
                (ev.args.to as string).toLowerCase() !==
                DAO_MULTISIG.toLowerCase()
            )
                throw new Error('Released.to mismatch');
            if (!(ev.args.amount as BigNumber).eq(SHORTFALL_ZKP_WEI))
                throw new Error('Released.amount mismatch');

            const balAfter: BigNumber = await zkp.balanceOf(DAO_MULTISIG);
            if (!balAfter.sub(before.daoZkp).eq(SHORTFALL_ZKP_WEI))
                throw new Error(
                    `DAO ZKP delta ${balAfter.sub(before.daoZkp)} != SHORTFALL`,
                );

            const pool = await vp.getPool(newPoolId);
            if (!BigNumber.from(pool.vested).eq(SHORTFALL_ZKP_WEI))
                throw new Error('pool.vested != SHORTFALL after action 3');
            console.log(
                `    DAO ZKP +${SHORTFALL_ZKP_WEI}  pool.vested=${pool.vested}`,
            );
        },
        async () => ({daoZkp: await zkp.balanceOf(DAO_MULTISIG)}),
    );

    // ---- Action 4: releaseTo Base ----
    await runDirect(
        '4',
        action4.description,
        action4.to,
        action4.data,
        async (receipt: any, before: any) => {
            const ev = findEvent(
                receipt,
                vp.interface,
                'Released',
                VESTING_POOLS,
            );
            if (!ev) throw new Error('Released (Base) not emitted');
            if ((ev.args.poolId as BigNumber).toNumber() !== newPoolId)
                throw new Error('Released.poolId mismatch');
            if (
                (ev.args.to as string).toLowerCase() !==
                BASE_DEPLOYER_WALLET.toLowerCase()
            )
                throw new Error('Released.to mismatch');
            if (!(ev.args.amount as BigNumber).eq(BASE_AMOUNT_WEI))
                throw new Error('Released.amount mismatch');

            const balAfter: BigNumber = await zkp.balanceOf(
                BASE_DEPLOYER_WALLET,
            );
            if (!balAfter.sub(before.baseZkp).eq(BASE_AMOUNT_WEI))
                throw new Error(
                    `Base ZKP delta ${balAfter.sub(
                        before.baseZkp,
                    )} != BASE_AMOUNT`,
                );

            const pool = await vp.getPool(newPoolId);
            if (!BigNumber.from(pool.vested).eq(POOL_AMOUNT_WEI))
                throw new Error('pool.vested != POOL_AMOUNT after action 4');

            const remaining: BigNumber = await vp.releasableAmount(newPoolId);
            if (!remaining.eq(0))
                throw new Error(
                    `releasable != 0 after both releases (got ${remaining})`,
                );

            console.log(
                `    Base ZKP +${BASE_AMOUNT_WEI}  pool.vested=${pool.vested}  releasable=0`,
            );
        },
        async () => ({baseZkp: await zkp.balanceOf(BASE_DEPLOYER_WALLET)}),
    );

    // ---- Action 5: approve ----
    await runDirect(
        '5',
        action5.description,
        action5.to,
        action5.data,
        async (receipt: any) => {
            const ev = findEvent(receipt, zkp.interface, 'Approval', ZKP);
            if (!ev) throw new Error('Approval not emitted');
            if (
                (ev.args.owner as string).toLowerCase() !==
                DAO_MULTISIG.toLowerCase()
            )
                throw new Error('Approval.owner mismatch');
            if (
                (ev.args.spender as string).toLowerCase() !==
                ERC20_PREDICATE.toLowerCase()
            )
                throw new Error('Approval.spender mismatch');
            if (!(ev.args.value as BigNumber).eq(SHORTFALL_ZKP_WEI))
                throw new Error('Approval.value mismatch');

            const allowance: BigNumber = await zkp.allowance(
                DAO_MULTISIG,
                ERC20_PREDICATE,
            );
            if (!allowance.gte(SHORTFALL_ZKP_WEI))
                throw new Error(`allowance ${allowance} < SHORTFALL`);
            console.log(`    allowance(DAO→predicate)=${allowance}`);
        },
    );

    // ---- Action 6: depositFor ----
    await runDirect(
        '6',
        action6.description,
        action6.to,
        action6.data,
        async (receipt: any, before: any) => {
            const lockedEv = findEvent(
                receipt,
                predicateIface,
                'LockedERC20',
                ERC20_PREDICATE,
            );
            if (!lockedEv)
                throw new Error('LockedERC20 not emitted by predicate');
            if (
                (lockedEv.args.depositor as string).toLowerCase() !==
                DAO_MULTISIG.toLowerCase()
            )
                throw new Error('LockedERC20.depositor mismatch');
            if (
                (lockedEv.args.depositReceiver as string).toLowerCase() !==
                VAULT_POLYGON.toLowerCase()
            )
                throw new Error('LockedERC20.depositReceiver mismatch');
            if (
                (lockedEv.args.rootToken as string).toLowerCase() !==
                ZKP.toLowerCase()
            )
                throw new Error('LockedERC20.rootToken mismatch');
            if (!(lockedEv.args.amount as BigNumber).eq(SHORTFALL_ZKP_WEI))
                throw new Error('LockedERC20.amount mismatch');

            const daoAfter: BigNumber = await zkp.balanceOf(DAO_MULTISIG);
            const predicateAfter: BigNumber = await zkp.balanceOf(
                ERC20_PREDICATE,
            );
            if (!before.daoZkp.sub(daoAfter).eq(SHORTFALL_ZKP_WEI))
                throw new Error(
                    `DAO ZKP delta wrong: ${before.daoZkp.sub(daoAfter)}`,
                );
            if (!predicateAfter.sub(before.predicateZkp).eq(SHORTFALL_ZKP_WEI))
                throw new Error(
                    `Predicate ZKP delta wrong: ${predicateAfter.sub(
                        before.predicateZkp,
                    )}`,
                );
            console.log(
                `    DAO ZKP −${SHORTFALL_ZKP_WEI}  Predicate ZKP +${SHORTFALL_ZKP_WEI}`,
            );
        },
        async () => ({
            daoZkp: await zkp.balanceOf(DAO_MULTISIG),
            predicateZkp: await zkp.balanceOf(ERC20_PREDICATE),
        }),
    );

    // ===================================================================
    // Bridge wrappers 7..8 — assert StateSynced emitted by StateSender
    // ===================================================================
    const stateSyncedTopic = hre.ethers.utils.id(
        'StateSynced(uint256,address,bytes)',
    );

    for (let i = 0; i < bridgeMessages.length; i++) {
        const m = bridgeMessages[i];
        const order = ethFile.actions.length + i + 1;
        const wrapperData = fxRootIface.encodeFunctionData(
            'sendMessageToChild',
            [BRIDGE_ADDRESSES.maticBridgeModule, m.encodedPayload],
        );

        console.log(
            `--- Tx #${order} [bridge]: ${m.description.slice(0, 90)} ---`,
        );
        console.log(`  Bridge nonce: ${m.bridgeNonce}`);
        const receipt = await (
            await daoSigner.sendTransaction({
                to: BRIDGE_ADDRESSES.fxRoot,
                data: wrapperData,
                gasLimit: 1_000_000,
            })
        ).wait();
        console.log(
            `  TX succeeded: ${receipt.transactionHash} (gas: ${receipt.gasUsed})`,
        );

        const stateSyncLog = receipt.logs.find(
            (log: any) => log.topics[0] === stateSyncedTopic,
        );
        if (!stateSyncLog) throw new Error('StateSynced not emitted');
        const stateId = hre.ethers.BigNumber.from(stateSyncLog.topics[1]);
        console.log(`  StateSynced emitted (stateId: ${stateId})`);
        console.log(`  PASS\n`);
    }

    console.log(
        `=== All ${
            ethFile.actions.length + bridgeMessages.length
        } transactions executed and asserted successfully ===`,
    );

    // ---- Helper: send a direct tx, run pre/post hooks ----
    async function runDirect(
        order: string,
        description: string,
        to: string,
        data: string,
        post: (receipt: any, before: any) => Promise<void>,
        pre?: () => Promise<any>,
    ): Promise<void> {
        console.log(
            `--- Tx #${order} [direct]: ${description.slice(0, 90)} ---`,
        );
        const before = pre ? await pre() : {};
        const receipt = await (
            await daoSigner.sendTransaction({to, data, gasLimit: 1_000_000})
        ).wait();
        console.log(
            `  TX succeeded: ${receipt.transactionHash} (gas: ${receipt.gasUsed})`,
        );
        await post(receipt, before);
        console.log(`  PASS\n`);
    }
});

function findEvent(
    receipt: {logs?: any[]; events?: any[]},
    iface: any,
    eventName: string,
    address?: string,
): {args: any; name: string} | null {
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
}

export {};
