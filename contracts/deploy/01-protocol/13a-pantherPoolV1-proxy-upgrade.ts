// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getNamedAccount,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const pantherPoolV1Proxy = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        '',
    );
    const pantherPoolV1Impl = await getContractAddress(
        hre,
        'PantherPoolV1_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        pantherPoolV1Proxy,
        pantherPoolV1Impl,
        'PoolV1',
    );
};

export default func;

func.tags = ['pool-v1-upgrade', 'protocol'];
func.dependencies = [
    'check-params',
    'deployment-consent',
    'pool-v1-proxy',
    'pool-v1-imp',
];
