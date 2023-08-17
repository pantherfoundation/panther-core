// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts} = hre;
    const {deployer} = await getNamedAccounts();

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
func.dependencies = ['check-params', 'bus-tree-impl'];
