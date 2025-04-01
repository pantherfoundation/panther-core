// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {safeAddFacetToDiamond} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    await safeAddFacetToDiamond(
        hre,
        coreDiamond,
        'FeeMasterTotalDebtController',
    );
};
export default func;

func.tags = [
    'add-fee-master-total-debt-controller',
    'core',
    'core-add-facet',
    'protocol-v1',
];
func.dependencies = [
    'fee-master-total-debt-controller',
    'add-core-diamond-loupe',
    'core-diamond',
];
