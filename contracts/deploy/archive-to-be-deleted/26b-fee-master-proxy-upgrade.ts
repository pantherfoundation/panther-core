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

    const feeMasterProxy = await getContractAddress(hre, 'FeeMaster_Proxy', '');
    const feeMasterImpl = await getContractAddress(
        hre,
        'FeeMaster_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        feeMasterProxy,
        feeMasterImpl,
        'FeeMaster',
    );
};

export default func;

func.tags = ['fee-master-upgrade', 'protocol'];
func.dependencies = [
    'deployment-consent',
    'fee-master-proxy',
    'fee-master-imp',
];
