// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
        ethers,
    } = hre;

    await deploy('Paymaster_Proxy', {
        contract: 'EIP173ProxyWithReceive',
        from: deployer,
        args: [
            ethers.constants.AddressZero, // implementation will be changed
            deployer, // owner will be changed
            [], // data
        ],
        log: true,
        autoMine: true,
        gasPrice: 25000000000,
    });
};
export default func;

func.tags = ['paymaster-proxy', 'protocol-v1'];
