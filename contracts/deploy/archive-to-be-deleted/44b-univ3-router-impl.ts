// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    getNamedAccount,
    attemptVerify,
} from '../../lib/deploymentHelpers';

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
