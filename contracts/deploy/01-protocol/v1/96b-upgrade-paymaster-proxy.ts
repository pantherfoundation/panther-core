// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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

    const paymasterProxy = (await get('Paymaster_Proxy')).address;
    const paymasterImp = (await get('PayMaster_Implementation')).address;

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        paymasterProxy,
        paymasterImp,
        'Paymaster',
    );
};
export default func;

func.tags = ['upgrade-paymaster-proxy'];
func.dependencies = ['paymaster-imp', 'paymaster-proxy'];
