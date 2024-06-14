// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../lib/deploymentHelpers';

import {attemptVerify} from './common/tenderly';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    await deploy('MockUniswapV3Factory', {
        contract: 'MockUniswapV3Factory',
        from: deployer,
        args: [],
        log: true,
        autoMine: true,
    });

    await attemptVerify(
        hre,
        'MockUniswapV3Factory_Implementation',
        '0xEB81E484610a3c7edbFe30AFb906a5D9ABeA6D60',
    );
};
export default func;

func.tags = ['univ3-factory'];
func.dependencies = ['check-params', 'deployment-consent'];
