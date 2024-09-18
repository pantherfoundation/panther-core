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

    const busTreeProxy = await getContractAddress(
        hre,
        'PantherBusTree_Proxy',
        '',
    );
    const busTreeImpl = await getContractAddress(
        hre,
        'PantherBusTree_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        busTreeProxy,
        busTreeImpl,
        'PantherBusTree',
    );
};

export default func;

func.tags = ['bus-tree-upgrade', 'protocol'];
func.dependencies = [
    'check-params',
    'deployment-consent',
    'bus-tree-proxy',
    'bus-tree-impl',
];
