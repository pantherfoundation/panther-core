// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getNamedAccount,
    reuseEnvAddress,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    console.log(deployer);
    const {
        deployments: {deploy},
        ethers,
    } = hre;

    await verifyUserConsentOnProd(hre, deployer);

    if (reuseEnvAddress(hre, 'LINK_TOKEN_PROXY')) return;

    await deploy('MockUniSwapV3Router_Proxy', {
        contract: 'EIP173ProxyWithReceive',
        from: deployer,
        args: [
            ethers.constants.AddressZero, // implementation will be changed
            deployer, // owner will be changed
            [], // data
        ],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['univ3-router-proxy'];
func.dependencies = ['check-params', 'deployment-consent'];
