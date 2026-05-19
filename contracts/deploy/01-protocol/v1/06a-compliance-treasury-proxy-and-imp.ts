// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
    } = hre;

    const feeMasterProxy = (await get('FeeMaster')).address;

    await deploy('ComplianceTreasury', {
        from: deployer,
        args: [multisig, pzkp, feeMasterProxy],
        proxy: {
            proxyContract: 'EIP173ProxyWithReceive',
            owner: multisig,
        },
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = [
    'compliance-treasury',
    'core',
    'protocol-v1',
    'protocol-v1-deploy',
];
func.dependencies = ['fee-master-proxy'];
