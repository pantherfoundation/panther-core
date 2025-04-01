// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {safeAddFacetToDiamond} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
    } = hre;

    const treesDiamond = (await get('PantherTrees')).address;
    const facetName = 'BlacklistedZAccountsIdsRegistry';

    console.log(`adding ${facetName} facet to trees diamond...`);

    await safeAddFacetToDiamond(hre, treesDiamond, facetName);
};
export default func;

func.tags = [
    'add-blacklisted-zaccount-ids-registry',
    'trees',
    'trees-add-facet',
    'protocol-v1',
];
func.dependencies = [
    'blacklisted-zaccount-ids-registry',
    'add-trees-diamond-loupe',
    'trees-diamond',
];
