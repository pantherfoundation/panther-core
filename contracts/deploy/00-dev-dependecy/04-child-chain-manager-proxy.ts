// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {
        deployments: {deploy},
        ethers,
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();

    await deploy('MockChildChainManager_Proxy', {
        contract: 'EIP173Proxy',
        from: deployer,
        args: [
            ethers.constants.AddressZero, // implementation will be changed
            deployer, // owner
            [], // data
        ],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['child-chain-manager-proxy', 'dev-dependency'];
