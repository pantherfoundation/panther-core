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

    const taxiTree = await getContractAddress(hre, 'PantherTaxiTree', '');
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
    const prpConverterProxy = await getContractAddress(
        hre,
        'PrpConverter_Proxy',
        '',
    );

    const pantherVerifier = await getContractAddress(
        hre,
        'PantherVerifier',
        'PANTHER_VERIFIER',
    );

    const poseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;
    const poseidonT4 =
        getContractEnvAddress(hre, 'POSEIDON_T4') ||
        (await get('PoseidonT4')).address;

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
            prpConverterProxy,
            pantherVerifier,
        ],
        libraries: {
            PoseidonT3: poseidonT3,
            PoseidonT4: poseidonT4,
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
    'pzkp-token',
    'taxi-tree',
    'bus-tree-proxy',
    'ferry-tree',
    'static-tree-proxy',
    'z-accounts-registry-proxy',
    'prp-converter-proxy',
    'prp-voucher-grantor',
    'verifier',
    'crypto-libs',
    'vault-proxy',
];
