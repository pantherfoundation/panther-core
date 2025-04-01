// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {addFacetToDiamond} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
    } = hre;

    const treesDiamond = (await get('PantherTrees')).address;

    try {
        console.log('Adding DiamondLoupeFacet to the PantherTrees...');

        const res = await addFacetToDiamond(
            hre,
            treesDiamond,
            'DiamondLoupeFacet',
        );
        console.log('Transaction confirmed', res.transactionHash);
    } catch (error) {
        if (
            error.message.includes(
                "LibDiamondCut: Can't add function that already exists",
            )
        ) {
            console.log('DiamondLoupeFacet Already exists');
        } else {
            throw new Error(error);
        }
    }
};
export default func;

func.tags = [
    'add-trees-diamond-loupe',
    'core',
    'core-add-facet',
    'protocol-v1',
];
func.dependencies = ['diamond-loupe-facet', 'core-diamond'];
