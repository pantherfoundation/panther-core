// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const trustProvider = await getNamedAccount(hre, 'trustProvider');
    const weth9 = await getNamedAccount(hre, 'weth9');
    const pantherTreasury = await getNamedAccount(hre, 'pantherTreasury');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;
    const treesDiamond = (await get('PantherTrees')).address;
    const vaultV1 = (await get('VaultV1')).address;
    const paymaster = (await get('Paymaster_Proxy')).address;

    const providers = {
        pantherPool: coreDiamond,
        pantherTrees: treesDiamond,
        paymaster,
        trustProvider,
    };

    await deploy('FeeMaster', {
        from: deployer,
        args: [multisig, providers, pzkp, weth9, vaultV1, pantherTreasury],
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: multisig,
        },
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = ['fee-master', 'core', 'protocol-v1'];
func.dependencies = [
    'core-diamond',
    'trees-diamond',
    'paymaster-proxy',
    'vault-v1',
];
