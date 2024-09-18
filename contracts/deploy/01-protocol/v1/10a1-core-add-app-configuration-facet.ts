// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {safeAddFacetToDiamond} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    await safeAddFacetToDiamond(hre, coreDiamond, 'AppConfiguration');
};

export default func;

func.tags = ['add-app-configuration', 'core', 'core-add-facet', 'protocol-v1'];
func.dependencies = [
    'app-configuration',
    'add-core-diamond-loupe',
    'core-diamond',
];
