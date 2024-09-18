// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getNamedAccount,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const proxyAddr = '0xA82B5942DD61949Fd8A2993dCb5Ae6736F8F9E60';

    const implAddr = '0x7d83c001Ce630b3282e20123f573D3fD776958EA';

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        proxyAddr,
        implAddr,
        'LinkTokenMock',
    );
};

export default func;

func.tags = ['link-token-upgrade'];
func.dependencies = ['check-params', 'deployment-consent'];
