// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
//
// PIP-38 — Advanced-staking claim window: Ethereum-side unit test.
//
// Runs every Ethereum action in the proposal against a forked Ethereum
// mainnet at the latest block, asserting both emitted events AND
// storage / view-method state after each action. Writes the captured
// tx details to `PIP-38-ethereum-actions.json` at the contracts/ root
// at the end of the run — that file is the input to the cross-chain
// proposal generation agent (see contracts/tasks/GOVERNANCE.md).
//
// ─────────────────────────────────────────────────────────────────────
// HOW TO RUN — read the live latest Ethereum block, then run:

/**
 

   LATEST_ETH=$(curl -s -X POST "$ETHEREUM_RPC" \
       -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' \
       | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))")

   HARDHAT_FORKING_URL="https://eth-mainnet.g.alchemy.com/v2/-bbwqZtH2RJk3xclZ2ccJPa9yik86KQC" \
   HARDHAT_FORKING_ENABLED=1 \
   HARDHAT_FORKING_BLOCK=25223570 \
     npx hardhat test test/protocol/PIP38EthereumActions.forked.spec.ts

 */

// ─────────────────────────────────────────────────────────────────────

import {expect} from 'chai';
import {BigNumber, Contract, ContractTransaction} from 'ethers';
import * as fs from 'fs';
import * as path from 'path';
import {ethers, network} from 'hardhat';

// ===== Constants (mainnet) =====

const DAO_MULTISIG = '0x505796f5bc290269d2522cf19135ad7aa60dfd77';
const VESTING_POOLS = '0xb476104aa9D1f30180a01987FB09b1e96dDCF14B';
const ZKP = '0x909E34d3f6124C324ac83DccA84b74398a6fa173';
const ERC20_PREDICATE = '0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf';
const ROOT_CHAIN_MANAGER = '0xA0c68C638235ee32657e8f720a23ceC1bFc77C77';
const VAULT_POLYGON = '0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9';

// Base ecosystem-rewards deployer wallet — receives the 4M ZKP on Ethereum;
// the bridge to Base is performed manually outside this proposal.
const BASE_DEPLOYER_WALLET = '0xeE3c1dDBCB795ff2fA12330149DEA0369bF03742';

// VestingPools.PoolParams.sAllocation is uint48 (max 2^48-1 ≈ 2.81e14) and the
// actual allocation in wei is sAllocation * SCALE where SCALE = 1e12. ZKP has
// 18 decimals, so for X.YYY ZKP we use sAllocation = X.YYY * 1e6.
const SCALE = BigNumber.from(10).pow(12);

// ----- Single pool sized as (claim-window shortfall) + (Base allocation) -----
// • 392,496.050189148592083079 ZKP — exact shortfall from build-claim-data.ts.
//   The 1e-12 scale boundary lets us represent at most 6 fractional digits;
//   we round UP so the pool covers the shortfall (with a negligible ≈ 8.5e-10
//   ZKP surplus that ends up sweepable from the Polygon Vault after the
//   1-year claim window).
//     sAllocation contribution: 392_496_050_190
//
// • 5,100,000 ZKP — Base ecosystem-rewards allocation.
//     sAllocation contribution: 5_100_000_000_000
//
// Total pool sAllocation = 5_492_496_050_190 (≈ 5.49e12, well within uint48).
const POOL_S_ALLOCATION = BigNumber.from('5492496050190');
const POOL_AMOUNT_WEI = POOL_S_ALLOCATION.mul(SCALE); // 5,492,496.05019 ZKP

// Sub-allocations (in wei):
const SHORTFALL_ZKP_WEI = BigNumber.from('392496050190').mul(SCALE); // 392,496.05019 ZKP — to DAO, then bridged
const BASE_AMOUNT_WEI = BigNumber.from('5100000000000').mul(SCALE); // 5,100,000 ZKP — to Base deployer

// Hardcoded next pool id — VestingPools has 23 pools today (ids 0..22),
// verified on-chain at the time this spec was written. The precondition
// below asserts that getPool(NEW_POOL_ID) reverts, so the test will fail
// loudly if a new pool gets added before this proposal executes.
const NEW_POOL_ID = 23;

const POOL_VESTING_DAYS = 1;
const POOL_START_FUTURE_OFFSET_SECS = 35 * 24 * 60 * 60;
const POOL_START_PAST_OFFSET_SECS = 2 * 24 * 60 * 60;

// Simulated delay between proposal generation (when the calldata is built
// against `nowBase`) and the moment the DAO Multisig actually executes it.
// A Panther Snapshot vote runs ~3 days and execution typically lands a day
// after, so we fast-forward the chain by 4 days before sending any tx. This
// proves the captured calldata is still valid AFTER realistic governance
// latency:
//   • addVestingPools requires `pools[i].start >= block.timestamp`. With
//     start = nowBase + 35d and chain at nowBase + 4d, 35d − 4d = 31d of
//     headroom remains.
//   • updatePoolTime requires `_timeNow() > end` where end = start + 1d.
//     With start = nowBase − 2d, end = nowBase − 1d, chain at nowBase + 4d
//     → 5d into the past. Safe.
// If governance is delayed past ~31 days from generation, the spec catches
// it: addVestingPools would revert with `VPools: start already passed`.
const DAO_EXECUTION_DELAY_SECS = 4 * 24 * 60 * 60;

const OUTPUT_FILE = path.join(
    __dirname,
    '..',
    '..',
    'PIP-38-ethereum-actions.json',
);

// ===== ABIs =====

const vestingPoolsAbi = [
    'function owner() view returns (address)',
    'function getPool(uint256 poolId) view returns (tuple(bool isPreMinted, bool isAdjustable, uint32 start, uint16 vestingDays, uint48 sAllocation, uint48 sUnlocked, uint96 vested))',
    'function getWallet(uint256 poolId) view returns (address)',
    'function totalAllocation() view returns (uint96)',
    'function releasableAmount(uint256 poolId) view returns (uint256)',
    'function addVestingPools(address[] wallets, tuple(bool isPreMinted, bool isAdjustable, uint32 start, uint16 vestingDays, uint48 sAllocation, uint48 sUnlocked, uint96 vested)[] pools) external',
    'function updatePoolTime(uint256 poolId, uint32 start, uint16 vestingDays) external',
    'function releaseTo(uint256 poolId, address account, uint256 amount) external returns (uint256)',
    'event PoolAdded(uint256 indexed poolId, address indexed wallet, uint256 allocation)',
    'event PoolUpdated(uint256 indexed poolId, uint256 start, uint256 vestingDays)',
    'event Released(uint256 indexed poolId, address to, uint256 amount)',
];

const erc20Abi = [
    'function balanceOf(address) view returns (uint256)',
    'function allowance(address owner, address spender) view returns (uint256)',
    'function approve(address spender, uint256 amount) returns (bool)',
    'event Approval(address indexed owner, address indexed spender, uint256 value)',
    'event Transfer(address indexed from, address indexed to, uint256 value)',
];

const rootChainManagerAbi = [
    'function depositFor(address user, address rootToken, bytes depositData) external',
];

// LockedERC20 emitted by the ERC20Predicate when depositFor locks tokens.
const erc20PredicateAbi = [
    'event LockedERC20(address indexed depositor, address indexed depositReceiver, address indexed rootToken, uint256 amount)',
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

describe('PIP-38 Phase A — Ethereum actions on a forked Ethereum mainnet', function () {
    this.timeout(10 * 60 * 1000);

    let vp: Contract;
    let zkp: Contract;
    let rcm: Contract;
    let dao: ReturnType<typeof ethers.provider.getSigner>;

    let blockTimestamp: number;
    let startFuture: number;
    let startPast: number;
    const newPoolId = NEW_POOL_ID;

    before(async () => {
        if (!process.env.HARDHAT_FORKING_ENABLED) {
            throw new Error(
                'This spec requires HARDHAT_FORKING_ENABLED=1 + HARDHAT_FORKING_URL set to an Ethereum mainnet RPC.',
            );
        }
        const chainId = (await ethers.provider.getNetwork()).chainId;
        if (chainId !== 1 && chainId !== 31337) {
            throw new Error(
                `expected Ethereum mainnet (1) or hardhat (31337), got ${chainId}`,
            );
        }

        const latest = await ethers.provider.getBlock('latest');
        blockTimestamp = latest.timestamp;

        // Use wall-clock "now" as the base for the pool's start timestamps.
        // The captured calldata then anchors to real time, not to whatever
        // block the fork happened to be pinned at. Wall-clock is always ≥
        // the latest block's timestamp, so:
        //   • startFuture = now + 35d  →  satisfies `start >= block.timestamp`
        //     at proposal-execution time (addVestingPools requirement).
        //   • startPast   = now - 2d   →  in the past relative to the chain's
        //     `_timeNow()`, satisfying `_timeNow() > new_end` (updatePoolTime
        //     requirement) since new_end = startPast + 1 day is still in the
        //     past.
        const nowBase = Math.floor(Date.now() / 1000);
        startFuture = nowBase + POOL_START_FUTURE_OFFSET_SECS;
        startPast = nowBase - POOL_START_PAST_OFFSET_SECS;
        console.log(
            `  fork block ${
                latest.number
            }  block ts ${blockTimestamp} (${new Date(
                blockTimestamp * 1000,
            ).toISOString()})`,
        );
        console.log(
            `  base time (wall-clock now): ${nowBase} (${new Date(
                nowBase * 1000,
            ).toISOString()})`,
        );
        console.log(`  startFuture = ${startFuture}  startPast = ${startPast}`);

        vp = new ethers.Contract(
            VESTING_POOLS,
            vestingPoolsAbi,
            ethers.provider,
        );
        zkp = new ethers.Contract(ZKP, erc20Abi, ethers.provider);
        rcm = new ethers.Contract(
            ROOT_CHAIN_MANAGER,
            rootChainManagerAbi,
            ethers.provider,
        );

        dao = await impersonate(DAO_MULTISIG);
    });

    it('precondition: VestingPools.owner == DAO_MULTISIG', async () => {
        const owner: string = await vp.owner();
        expect(owner.toLowerCase()).to.equal(DAO_MULTISIG.toLowerCase());
    });

    it('precondition: shortfall + Base sub-allocations equal the pool total', () => {
        expect(SHORTFALL_ZKP_WEI.add(BASE_AMOUNT_WEI).toString()).to.equal(
            POOL_AMOUNT_WEI.toString(),
        );
    });

    it(`simulates a ${
        DAO_EXECUTION_DELAY_SECS / 86400
    }-day DAO execution delay (fast-forwards chain time)`, async () => {
        // The captured calldata anchors to `nowBase` (wall-clock at simulation
        // time). In production, the proposal is sent through a Snapshot vote
        // (~3 days) and then a Safe execution that lands a bit later, so by
        // the time `addVestingPools` actually runs, the chain timestamp will
        // be several days past `nowBase`. We move the fork's clock forward
        // by ${DAO_EXECUTION_DELAY_SECS / 86400} days here to mirror that
        // and prove the timestamps in the captured calldata remain valid.
        const targetTimestamp =
            Math.floor(Date.now() / 1000) + DAO_EXECUTION_DELAY_SECS;
        await network.provider.send('evm_setNextBlockTimestamp', [
            targetTimestamp,
        ]);
        await network.provider.send('evm_mine', []);

        const newBlock = await ethers.provider.getBlock('latest');
        console.log(
            `  chain advanced to ${newBlock.timestamp} (${new Date(
                newBlock.timestamp * 1000,
            ).toISOString()})`,
        );
        // Confirm the chain is now between (startPast + 1 day) and startFuture
        // — the window in which the captured calldata is valid.
        expect(newBlock.timestamp).to.be.greaterThan(startPast + 86400);
        expect(newBlock.timestamp).to.be.lessThan(startFuture);
    });

    it('Action 1 — addVestingPools (single combined pool): PoolAdded event + struct in storage', async () => {
        const totalAllocBefore: BigNumber = await vp.totalAllocation();

        const poolParams = {
            isPreMinted: false,
            isAdjustable: true,
            start: startFuture,
            vestingDays: POOL_VESTING_DAYS,
            sAllocation: POOL_S_ALLOCATION,
            sUnlocked: POOL_S_ALLOCATION,
            vested: 0,
        };
        const tx1 = await vp.populateTransaction.addVestingPools(
            [DAO_MULTISIG],
            [poolParams],
        );
        const sent: ContractTransaction = await dao.sendTransaction(tx1);
        const receipt = await sent.wait();

        // Event check
        const ev = findEvent(receipt, vp.interface, 'PoolAdded', VESTING_POOLS);
        expect(ev, 'PoolAdded not emitted').to.not.equal(null);
        expect((ev!.args.poolId as BigNumber).toNumber()).to.equal(newPoolId);
        expect((ev!.args.wallet as string).toLowerCase()).to.equal(
            DAO_MULTISIG.toLowerCase(),
        );
        expect((ev!.args.allocation as BigNumber).toString()).to.equal(
            POOL_AMOUNT_WEI.toString(),
        );

        // Storage / view check
        const pool = await vp.getPool(newPoolId);
        expect(pool.isPreMinted).to.equal(false);
        expect(pool.isAdjustable).to.equal(true);
        expect(pool.start).to.equal(startFuture);
        expect(pool.vestingDays).to.equal(POOL_VESTING_DAYS);
        expect(pool.sAllocation.toString()).to.equal(
            POOL_S_ALLOCATION.toString(),
        );
        expect(pool.sUnlocked.toString()).to.equal(
            POOL_S_ALLOCATION.toString(),
        );
        expect(pool.vested.toString()).to.equal('0');
        expect((await vp.getWallet(newPoolId)).toLowerCase()).to.equal(
            DAO_MULTISIG.toLowerCase(),
        );

        const totalAllocAfter: BigNumber = await vp.totalAllocation();
        expect(totalAllocAfter.sub(totalAllocBefore).toString()).to.equal(
            POOL_AMOUNT_WEI.toString(),
        );

        capture(
            1,
            `Create new vesting pool ${newPoolId} (5,492,496.05 ZKP — 392,496.05 for the claim-window APY shortfall + 5,100,000 for the Base ecosystem-rewards allocation) with the DAO multisig as wallet`,
            tx1,
            'addVestingPools(address[],(bool,bool,uint32,uint16,uint48,uint48,uint96)[])',
            [
                JSON.stringify([DAO_MULTISIG]),
                JSON.stringify([
                    {
                        isPreMinted: poolParams.isPreMinted,
                        isAdjustable: poolParams.isAdjustable,
                        start: poolParams.start,
                        vestingDays: poolParams.vestingDays,
                        sAllocation: poolParams.sAllocation.toString(),
                        sUnlocked: poolParams.sUnlocked.toString(),
                        vested: poolParams.vested,
                    },
                ]),
            ],
        );
    });

    it('Action 2 — updatePoolTime: start moved to past, full allocation immediately releasable', async () => {
        const tx2 = await vp.populateTransaction.updatePoolTime(
            newPoolId,
            startPast,
            POOL_VESTING_DAYS,
        );
        const receipt = await (await dao.sendTransaction(tx2)).wait();

        const ev = findEvent(
            receipt,
            vp.interface,
            'PoolUpdated',
            VESTING_POOLS,
        );
        expect(ev, 'PoolUpdated not emitted').to.not.equal(null);
        expect((ev!.args.poolId as BigNumber).toNumber()).to.equal(newPoolId);
        expect((ev!.args.start as BigNumber).toNumber()).to.equal(startPast);

        const pool = await vp.getPool(newPoolId);
        expect(pool.start).to.equal(startPast);

        const releasable: BigNumber = await vp.releasableAmount(newPoolId);
        expect(releasable.gte(POOL_AMOUNT_WEI)).to.equal(true);

        capture(
            2,
            `Move pool ${newPoolId} start time into the past so the 5,492,496.05 ZKP allocation becomes immediately releasable`,
            tx2,
            'updatePoolTime(uint256,uint32,uint16)',
            [String(newPoolId), String(startPast), String(POOL_VESTING_DAYS)],
        );
    });

    it('Action 3 — releaseTo: DAO multisig receives the 392,496.05 ZKP shortfall portion', async () => {
        const balBefore: BigNumber = await zkp.balanceOf(DAO_MULTISIG);
        const tx3 = await vp.populateTransaction.releaseTo(
            newPoolId,
            DAO_MULTISIG,
            SHORTFALL_ZKP_WEI,
        );
        const receipt = await (await dao.sendTransaction(tx3)).wait();
        const balAfter: BigNumber = await zkp.balanceOf(DAO_MULTISIG);

        const releasedEv = findEvent(
            receipt,
            vp.interface,
            'Released',
            VESTING_POOLS,
        );
        expect(releasedEv, 'Released not emitted').to.not.equal(null);
        expect((releasedEv!.args.poolId as BigNumber).toNumber()).to.equal(
            newPoolId,
        );
        expect((releasedEv!.args.to as string).toLowerCase()).to.equal(
            DAO_MULTISIG.toLowerCase(),
        );
        expect((releasedEv!.args.amount as BigNumber).toString()).to.equal(
            SHORTFALL_ZKP_WEI.toString(),
        );

        expect(balAfter.sub(balBefore).toString()).to.equal(
            SHORTFALL_ZKP_WEI.toString(),
        );

        const pool = await vp.getPool(newPoolId);
        expect(pool.vested.toString()).to.equal(SHORTFALL_ZKP_WEI.toString());

        capture(
            3,
            `Release 392,496.05 ZKP from pool ${newPoolId} to the DAO multisig — used to top up the Polygon Vault for the claim-window APY shortfall`,
            tx3,
            'releaseTo(uint256,address,uint256)',
            [String(newPoolId), DAO_MULTISIG, SHORTFALL_ZKP_WEI.toString()],
        );
    });

    it('Action 4 — releaseTo: Base deployer wallet receives 5,100,000 ZKP (the remainder)', async () => {
        const balBefore: BigNumber = await zkp.balanceOf(BASE_DEPLOYER_WALLET);
        const tx4 = await vp.populateTransaction.releaseTo(
            newPoolId,
            BASE_DEPLOYER_WALLET,
            BASE_AMOUNT_WEI,
        );
        const receipt = await (await dao.sendTransaction(tx4)).wait();
        const balAfter: BigNumber = await zkp.balanceOf(BASE_DEPLOYER_WALLET);

        const releasedEv = findEvent(
            receipt,
            vp.interface,
            'Released',
            VESTING_POOLS,
        );
        expect(releasedEv, 'Released not emitted').to.not.equal(null);
        expect((releasedEv!.args.poolId as BigNumber).toNumber()).to.equal(
            newPoolId,
        );
        expect((releasedEv!.args.to as string).toLowerCase()).to.equal(
            BASE_DEPLOYER_WALLET.toLowerCase(),
        );
        expect((releasedEv!.args.amount as BigNumber).toString()).to.equal(
            BASE_AMOUNT_WEI.toString(),
        );

        expect(balAfter.sub(balBefore).toString()).to.equal(
            BASE_AMOUNT_WEI.toString(),
        );

        // After both releases the pool's vested equals its full allocation.
        const pool = await vp.getPool(newPoolId);
        expect(pool.vested.toString()).to.equal(POOL_AMOUNT_WEI.toString());

        // And nothing else is releasable from the pool.
        const remaining: BigNumber = await vp.releasableAmount(newPoolId);
        expect(remaining.toString()).to.equal('0');

        capture(
            4,
            `Release 5,100,000 ZKP from pool ${newPoolId} to the Base deployer wallet — will be manually bridged to Base outside this proposal`,
            tx4,
            'releaseTo(uint256,address,uint256)',
            [
                String(newPoolId),
                BASE_DEPLOYER_WALLET,
                BASE_AMOUNT_WEI.toString(),
            ],
        );
    });

    it('Action 5 — approve: Approval event + allowance storage updated for the 392,496 bridge deposit', async () => {
        const txApprove = await zkp.populateTransaction.approve(
            ERC20_PREDICATE,
            SHORTFALL_ZKP_WEI,
        );
        const receipt = await (await dao.sendTransaction(txApprove)).wait();

        const ev = findEvent(receipt, zkp.interface, 'Approval', ZKP);
        expect(ev, 'Approval not emitted').to.not.equal(null);
        expect((ev!.args.owner as string).toLowerCase()).to.equal(
            DAO_MULTISIG.toLowerCase(),
        );
        expect((ev!.args.spender as string).toLowerCase()).to.equal(
            ERC20_PREDICATE.toLowerCase(),
        );
        expect((ev!.args.value as BigNumber).toString()).to.equal(
            SHORTFALL_ZKP_WEI.toString(),
        );

        const allowance: BigNumber = await zkp.allowance(
            DAO_MULTISIG,
            ERC20_PREDICATE,
        );
        expect(allowance.gte(SHORTFALL_ZKP_WEI)).to.equal(true);

        capture(
            5,
            `Approve the Polygon PoS bridge ERC-20 predicate to spend 392,496.05 ZKP from the DAO multisig`,
            txApprove,
            'approve(address,uint256)',
            [ERC20_PREDICATE, SHORTFALL_ZKP_WEI.toString()],
        );
    });

    it('Action 6 — depositFor: LockedERC20 event on the predicate + balances move correctly', async () => {
        const balBefore: BigNumber = await zkp.balanceOf(DAO_MULTISIG);
        const predicateBalBefore: BigNumber = await zkp.balanceOf(
            ERC20_PREDICATE,
        );

        const depositData = ethers.utils.defaultAbiCoder.encode(
            ['uint256'],
            [SHORTFALL_ZKP_WEI],
        );
        const txDeposit = await rcm.populateTransaction.depositFor(
            VAULT_POLYGON,
            ZKP,
            depositData,
        );
        const receipt = await (await dao.sendTransaction(txDeposit)).wait();

        // Balance check
        const balAfter: BigNumber = await zkp.balanceOf(DAO_MULTISIG);
        expect(balBefore.sub(balAfter).toString()).to.equal(
            SHORTFALL_ZKP_WEI.toString(),
        );
        const predicateBalAfter: BigNumber = await zkp.balanceOf(
            ERC20_PREDICATE,
        );
        expect(predicateBalAfter.sub(predicateBalBefore).toString()).to.equal(
            SHORTFALL_ZKP_WEI.toString(),
        );

        // Event check — LockedERC20 from the ERC20Predicate
        const predicateIface = new ethers.utils.Interface(erc20PredicateAbi);
        const lockedEv = findEvent(
            receipt,
            predicateIface,
            'LockedERC20',
            ERC20_PREDICATE,
        );
        expect(
            lockedEv,
            'LockedERC20 not emitted on the ERC-20 predicate',
        ).to.not.equal(null);
        expect((lockedEv!.args.depositor as string).toLowerCase()).to.equal(
            DAO_MULTISIG.toLowerCase(),
        );
        expect(
            (lockedEv!.args.depositReceiver as string).toLowerCase(),
        ).to.equal(VAULT_POLYGON.toLowerCase());
        expect((lockedEv!.args.rootToken as string).toLowerCase()).to.equal(
            ZKP.toLowerCase(),
        );
        expect((lockedEv!.args.amount as BigNumber).toString()).to.equal(
            SHORTFALL_ZKP_WEI.toString(),
        );

        capture(
            6,
            `Bridge 392,496.05 ZKP through the Polygon PoS bridge with the Vault proxy on Polygon as the recipient`,
            txDeposit,
            'depositFor(address,address,bytes)',
            [VAULT_POLYGON, ZKP, depositData],
        );
    });

    after(() => {
        const output = {
            proposalId: 'PIP-38',
            chain: 'ethereum',
            chainId: 1,
            executionMode: 'direct',
            executedAs: DAO_MULTISIG,
            capturedAt: {
                forkBlockTimestamp: blockTimestamp,
                forkBlockTimestampIso: new Date(
                    blockTimestamp * 1000,
                ).toISOString(),
            },
            notes: [
                'These 6 actions are direct Ethereum-side calls (no bridge wrapping).',
                'The cross-chain proposal generation agent (per contracts/tasks/GOVERNANCE.md) turns each into a Safe Transaction Builder entry with `to = <action.to>`.',
                'Pool start timestamps are derived from the forked block timestamp at simulation time. If the proposal will execute > ~30 days later, re-run this spec to refresh actions #1 and #2 (the timestamps inside their calldata).',
                'One combined vesting pool is created with total = 5,492,496.05 ZKP. Action #3 releases 392,496.05 ZKP to the DAO multisig (bridged to the Polygon Vault for the claim-window APY shortfall). Action #4 releases the remaining 5,100,000 ZKP to the Base deployer wallet (manually bridged to Base outside this proposal).',
            ],
            constants: {
                DAO_MULTISIG,
                VESTING_POOLS,
                ZKP,
                ERC20_PREDICATE,
                ROOT_CHAIN_MANAGER,
                VAULT_POLYGON,
                BASE_DEPLOYER_WALLET,
                SHORTFALL_ZKP_WEI: SHORTFALL_ZKP_WEI.toString(),
                BASE_AMOUNT_WEI: BASE_AMOUNT_WEI.toString(),
                POOL_S_ALLOCATION: POOL_S_ALLOCATION.toString(),
                POOL_AMOUNT_WEI: POOL_AMOUNT_WEI.toString(),
                POOL_VESTING_DAYS,
                newPoolId,
                startFuture,
                startPast,
            },
            actions: captured,
        };
        fs.writeFileSync(OUTPUT_FILE, JSON.stringify(output, null, 2));
        console.log(`\n  Wrote ${captured.length} actions to ${OUTPUT_FILE}\n`);
    });
});
