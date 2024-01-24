// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    abi,
    bytecode,
} from '../../deployments/ARCHIVE/externalAbis/PZkpToken.json';
import {isProd} from '../../lib/checkNetwork';
import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    await deploy('PZkp_token', {
        contract: {
            abi,
            bytecode,
        },
        from: deployer,
        args: [deployer],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['pzkp-token', 'protocol-token', 'dev-dependency'];
