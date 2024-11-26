// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    await deploy('AppConfiguration', {
        from: deployer,
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['app-configuration', 'core', 'core-facet', 'protocol-v1'];
