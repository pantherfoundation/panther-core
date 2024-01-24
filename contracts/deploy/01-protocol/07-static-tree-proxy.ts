// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getNamedAccount,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
        ethers,
    } = hre;
    await verifyUserConsentOnProd(hre, deployer);

    await deploy('PantherStaticTree_Proxy', {
        contract: 'EIP173Proxy',
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

func.tags = ['static-tree-proxy', 'forest', 'protocol'];
func.dependencies = ['crypto-libs'];
