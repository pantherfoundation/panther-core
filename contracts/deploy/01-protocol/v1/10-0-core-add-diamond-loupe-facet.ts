// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {addFacetToDiamond} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    try {
        console.log('Adding DiamondLoupeFacet to the PantherPoolV1...');

        const res = await addFacetToDiamond(
            hre,
            coreDiamond,
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

func.tags = ['add-core-diamond-loupe', 'core', 'core-add-facet', 'protocol-v1'];
func.dependencies = ['diamond-loupe-facet', 'core-diamond'];
