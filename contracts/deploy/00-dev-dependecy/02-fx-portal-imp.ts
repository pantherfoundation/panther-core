// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();

    const zkp = await getContractAddress(hre, 'Zkp_token', '');
    const pzkp = await getContractAddress(hre, 'PZkp_token', '');

    await deploy('MockFxPortal_Implementation', {
        contract: 'MockFxPortal',
        from: deployer,
        args: [deployer, zkp, pzkp],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['fx-portal', 'fx-portal-imp', 'dev-dependency'];
func.dependencies = ['zkp-imp', 'pzkp-token'];
