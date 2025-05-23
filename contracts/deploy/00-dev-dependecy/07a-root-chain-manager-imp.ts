// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {getContractEnvAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();

    const fxRoot = getContractEnvAddress(hre, 'FX_ROOT');
    const childChainManager = process.env.CHILD_CHAIN_MANAGER;
    const zkp = '<ADDRESS>';

    await deploy('MockRootChainManager_Implementation', {
        contract: 'MockRootChainManager',
        from: deployer,
        args: [fxRoot, childChainManager, zkp],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['root-chain-manager-imp'];
func.dependencies = ['check-params'];
