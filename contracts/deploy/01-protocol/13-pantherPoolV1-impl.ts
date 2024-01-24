// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getContractEnvAddress,
    getNamedAccount,
    getPZkpToken,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy, get},
    } = hre;

    const pZkp = await getPZkpToken(hre);

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    const taxiTree = await getContractAddress(hre, 'MockTaxiTree', '');
    const busTreeProxy = await getContractAddress(
        hre,
        'PantherBusTree_Proxy',
        '',
    );
    const ferryTree = await getContractAddress(hre, 'PantherFerryTree', '');
    const staticTreeProxy = await getContractAddress(
        hre,
        'PantherStaticTree_Proxy',
        '',
    );
    const zAccountsRegistryProxy = await getContractAddress(
        hre,
        'ZAccountsRegistry_Proxy',
        '',
    );

    const prpVoucherGrantor = await getContractAddress(
        hre,
        'PrpVoucherGrantor_Proxy',
        '',
    );

    const pantherVerifier = await getContractAddress(
        hre,
        'PantherVerifier',
        'PANTHER_VERIFIER',
    );

    const poseidonT4 =
        getContractEnvAddress(hre, 'POSEIDON_T4') ||
        (await get('PoseidonT4')).address;
    const poseidonT5 =
        getContractEnvAddress(hre, 'POSEIDON_T5') ||
        (await get('PoseidonT5')).address;

    await deploy('PantherPoolV1_Implementation', {
        contract: 'PantherPoolV1',
        from: deployer,
        args: [
            multisig,
            pZkp.address,
            taxiTree,
            busTreeProxy,
            ferryTree,
            staticTreeProxy,
            vaultProxy,
            zAccountsRegistryProxy,
            prpVoucherGrantor,
            pantherVerifier,
        ],
        libraries: {
            PoseidonT4: poseidonT4,
            PoseidonT5: poseidonT5,
        },
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['pool-v1-imp', 'forest', 'protocol'];
func.dependencies = [
    'check-params',
    'deployment-consent',
    'protocol-token',
    'taxi-tree',
    'bus-tree-proxy',
    'ferry-tree',
    'static-tree-proxy',
    'z-accounts-registry-proxy',
    'prp-voucher-grantor',
    'verifier',
    'crypto-libs',
    'vault-proxy',
];
