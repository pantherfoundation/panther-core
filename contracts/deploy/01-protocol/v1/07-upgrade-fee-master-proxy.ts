// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getNamedAccount,
    upgradeEIP1967Proxy,
} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {get},
    } = hre;

    const feeMasterImpl = await get('FeeMaster_Implementation');
    const feeMasterProxy = await get('FeeMaster_Proxy');

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        feeMasterProxy.address,
        feeMasterImpl.address,
        'FeeMaster',
    );
};
export default func;

func.tags = ['upgrade-fee-master', 'core', 'protocol-v1', 'protocol-v1-deploy'];
func.dependencies = ['fee-master-proxy', 'fee-master-impl'];
