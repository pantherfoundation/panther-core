// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    await deploy('ZAccountsRegistry_Proxy', {
        contract: 'EIP173Proxy',
        from: deployer,
        args: [
            // TODO: investigate reuse of MockFxPortal_Proxy
            // If set to `ethers.constants.AddressZero`, as it logically should
            // be, hardhat-deploy reuses the MockFxPortal_Proxy proxy instance
            // instead of deploying a new instance of the proxy contract
            deployer, // implementation will be changed
            deployer, // owner will be changed
            [], // data
        ],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['z-accounts-registry-proxy', 'protocol'];
func.dependencies = ['deployment-consent'];
