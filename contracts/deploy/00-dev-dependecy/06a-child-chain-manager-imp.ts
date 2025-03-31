// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    getContractEnvAddress,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();

    const fxChild = getContractEnvAddress(hre, 'FX_CHILD');
    const rootChainManager = process.env.ROOT_CHAIN_MANAGER;
    const pzkp = await getContractAddress(hre, 'PZkp_token', 'PZKP_TOKEN');

    console.log({fxChild, rootChainManager, pzkp});

    await deploy('MockChildChainManager_Implementation', {
        contract: 'MockChildChainManager',
        from: deployer,
        args: [deployer, fxChild, rootChainManager, pzkp],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['child-chain-manager-imp', 'dev-dependency'];
func.dependencies = ['check-params'];
