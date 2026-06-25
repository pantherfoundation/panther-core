// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
//
// Deploy the VaultV0Frozen implementation contract on Polygon.
//
// This script ONLY publishes the new implementation. It does NOT touch the
// Vault_Proxy — the proxy upgrade itself must be executed by the DAO multisig
// that owns the proxy admin. The script prints the upgrade calldata at the
// end so the multisig can submit it via Safe / Etherscan / etc.
//
// Required env vars:
//   VAULT_V0_FROZEN_OWNER    DAO multisig address. Will be set as `OWNER`
//                            (immutable) of the new implementation, and will
//                            be the only address able to call `setRoot`,
//                            `ownerSweepErc20`, `ownerSweepNft`.
//
// Optional env vars (Polygon production values used as defaults):
//   PZKP_TOKEN_POLYGON       ERC-20 ZKP token address.
//   PNFT_TOKEN_POLYGON       ERC-721 PNFT token address.
//   VAULT_PROXY_POLYGON      The Vault proxy address (used only to print the
//                            upgrade calldata).
//
// Run:
//   VAULT_V0_FROZEN_OWNER=0x... \
//     npx hardhat deploy --network polygon --tags vault-v0-frozen-impl

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    reuseEnvAddress,
    verifyUserConsentOnProd,
} from '../../../lib/deploymentHelpers';

// Polygon production addresses, verified on-chain:
//   PZkpToken:  contracts/deployments/ARCHIVE/production/polygon/PZkpToken.json
//   PNftToken:  contracts/deployments/ARCHIVE/production/polygon/PNftToken.json
//   VaultV0 proxy: the existing Vault_Proxy slated for upgrade.
const POLYGON_DEFAULTS = {
    zkpToken: '0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC',
    nftToken: '0xE5da4955cBC480Eb9Bf9534def229F9D8339eE6d',
    vaultProxy: '0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9',
    owner: '0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0',
};

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {deploy},
        getNamedAccounts,
        ethers,
        network,
    } = hre;
    const {deployer} = await getNamedAccounts();

    const isLocal = ['hardhat', 'localhost', 'pchain'].includes(network.name);
    if (network.name !== 'polygon' && !isLocal) {
        console.log(
            `VaultV0Frozen is only meant for Polygon. Skipping on '${network.name}'.`,
        );
        return;
    }

    await verifyUserConsentOnProd(hre, deployer);
    if (reuseEnvAddress(hre, 'VAULT_V0_FROZEN_IMP')) return;

    const zkpToken =
        process.env.PZKP_TOKEN_POLYGON || POLYGON_DEFAULTS.zkpToken;
    const nftToken =
        process.env.PNFT_TOKEN_POLYGON || POLYGON_DEFAULTS.nftToken;
    const vaultProxy =
        process.env.VAULT_PROXY_POLYGON || POLYGON_DEFAULTS.vaultProxy;
    const owner = process.env.VAULT_V0_FROZEN_OWNER || POLYGON_DEFAULTS.owner;

    console.log('\nDeploying VaultV0Frozen with:');
    console.log(`  owner (multisig): ${owner}`);
    console.log(`  ZKP_TOKEN:        ${zkpToken}`);
    console.log(`  NFT_TOKEN:        ${nftToken}`);
    console.log(`  (target proxy):   ${vaultProxy}`);

    const result = await deploy('VaultV0Frozen', {
        from: deployer,
        args: [owner, zkpToken, nftToken],
        log: true,
        autoMine: true,
    });

    if (!result.newlyDeployed) {
        console.log(`Already deployed at ${result.address}.`);
    }

    // Print the calldata the DAO multisig needs to execute to upgrade the
    // proxy. Standard EIP-1967 proxies expose `upgradeTo(address)` callable by
    // the proxy admin.
    const iface = new ethers.utils.Interface([
        'function upgradeTo(address newImplementation)',
    ]);
    const upgradeCalldata = iface.encodeFunctionData('upgradeTo', [
        result.address,
    ]);

    console.log(
        '\n=============================================================',
    );
    console.log('  Implementation deployed.');
    console.log(`  Address: ${result.address}`);
    console.log('');
    console.log('  Next step: the DAO multisig (proxy admin) executes:');
    console.log(`    to:    ${vaultProxy}`);
    console.log(`    value: 0`);
    console.log(`    data:  ${upgradeCalldata}`);
    console.log('');
    console.log('  After the upgrade:');
    console.log('    - PantherPoolV0.exit() and generateDeposits() revert');
    console.log('      with "VFrozen: frozen" — the v0 MASP is dead.');
    console.log('    - claim() still reverts ("VFrozen: not open") until the');
    console.log('      multisig submits a separate setRoot(root) tx.');
    console.log(
        '=============================================================\n',
    );
};

export default func;

func.tags = ['vault-v0-frozen-impl', 'protocol-v0'];
func.dependencies = [];
