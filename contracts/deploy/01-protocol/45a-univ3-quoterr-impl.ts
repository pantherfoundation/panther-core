// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    getNamedAccount,
} from '../../lib/deploymentHelpers';

// import {attemptVerify} from "./common/tenderly";

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

    await deploy('MockQuoterV2', {
        contract: 'MockQuoterV2',
        from: deployer,
        args: [uniswapV3MockFactoryAddress, wmaticAddress],
        log: true,
        autoMine: true,
    });
    // };

    // await attemptVerify(
    //     hre,
    //     "MockQuoterV2",
    //     "0x85Fa809EfF68DfC9a5d1Dd9e5Ff3ED5bd2D1741f"
    // );
};
export default func;

func.tags = ['univ3-quoter-impl'];
func.dependencies = ['check-params', 'deployment-consent'];
