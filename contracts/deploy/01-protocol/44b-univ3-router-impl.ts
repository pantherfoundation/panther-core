// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    getNamedAccount,
} from '../../lib/deploymentHelpers';

import {attemptVerify} from './common/tenderly';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const wmaticAddress = await getContractEnvAddress(hre, 'WMATIC_TOKEN');

    const uniswapV3MockFactoryAddress = await getContractEnvAddress(
        hre,
        'UNI_V3_FACTORY',
    );

    const {
        deployments: {deploy},
    } = hre;

    await deploy('MockUniSwapV3Router', {
        contract: 'MockUniSwapV3Router',
        from: deployer,
        args: [uniswapV3MockFactoryAddress, wmaticAddress],
        log: true,
        autoMine: true,
    });

    await attemptVerify(
        hre,
        'MockUniSwapV3Router',
        '0xB9E68AcBa9be97947325a78417d5146efa5F652D',
    );
};
export default func;

func.tags = ['univ3-router'];
func.dependencies = ['check-params', 'deployment-consent'];
