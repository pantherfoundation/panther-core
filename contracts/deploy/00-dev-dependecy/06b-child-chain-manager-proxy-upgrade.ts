// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {getNamedAccounts} = hre;
    const {deployer} = await getNamedAccounts();

    const mockChildChainManagerProxy = await getContractAddress(
        hre,
        'MockChildChainManager_Proxy',
        '',
    );
    const mockChildChainManagerImp = await getContractAddress(
        hre,
        'MockChildChainManager_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        mockChildChainManagerProxy,
        mockChildChainManagerImp,
        'MockChildChainManager',
    );
};

export default func;

func.tags = ['child-chain-manager-proxy-upgrade', 'dev-dependency'];
