// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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

    const mockRootChainManagerProxy = await getContractAddress(
        hre,
        'MockRootChainManager_Proxy',
        '',
    );
    const mockRootChainManagerImp = await getContractAddress(
        hre,
        'MockRootChainManager_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        mockRootChainManagerProxy,
        mockRootChainManagerImp,
        'MockRootChainManager',
    );
};

export default func;

func.tags = ['root-chain-manager-proxy-upgrade', 'dev-dependency'];
