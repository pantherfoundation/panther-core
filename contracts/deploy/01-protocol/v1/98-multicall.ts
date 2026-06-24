// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {getGasPrice} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    await deploy('Multicall', {
        from: deployer,
        log: true,
        autoMine: true,
        gasPrice: await getGasPrice(hre),
    });
};
export default func;

func.tags = ['multicall', 'core', 'protocol-v1', 'protocol-v1-deploy'];
