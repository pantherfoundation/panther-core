// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    await deploy('FeeMaster', {
        contract: 'EIP173ProxyWithReceive',
        from: deployer,
        args: ['0x0000000000000000000000000000000000000000', deployer, '0x'],
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = [
    'fee-master-proxy-only',
    'core',
    'protocol-v1',
    'protocol-v1-deploy',
];
func.dependencies = [];
