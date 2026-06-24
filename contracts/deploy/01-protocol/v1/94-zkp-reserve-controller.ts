// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {getGasPrice} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    await deploy('ZkpReserveController', {
        from: deployer,
        args: [multisig, pzkp, coreDiamond],
        log: true,
        autoMine: true,
        gasPrice: await getGasPrice(hre),
    });
};
export default func;

func.tags = [
    'zkp-reserve-controller',
    'core',
    'protocol-v1',
    'protocol-v1-deploy',
];
func.dependencies = ['core-diamond'];
