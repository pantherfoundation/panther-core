// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {safeAddFacetToDiamond} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
    } = hre;

    const treesDiamond = (await get('PantherTrees')).address;
    const facetName = 'ProvidersKeysRegistry';

    console.log(`adding ${facetName} facet to trees diamond...`);

    await safeAddFacetToDiamond(hre, treesDiamond, facetName);
};
export default func;

func.tags = [
    'add-providers-keys-registry',
    'trees',
    'trees-add-facet',
    'protocol-v1',
];
func.dependencies = [
    'providers-keys-registry',
    'add-trees-diamond-loupe',
    'trees-diamond',
];
