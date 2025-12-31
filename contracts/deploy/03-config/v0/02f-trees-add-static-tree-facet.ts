// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getSelectors} from '../../../lib/diamond';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const treesDiamond = await get('PantherTrees');
    const facetDeployment = await get('StaticTree');
    const facet = await ethers.getContractAt(
        facetDeployment.abi,
        facetDeployment.address,
    );

    const facetCut = {
        facetAddress: facet.address,
        action: 0,
        functionSelectors: getSelectors(facet),
    };

    const diamond = await ethers.getContractAt(
        'IDiamondCut',
        treesDiamond.address,
    );

    const tx = await diamond.populateTransaction.diamondCut(
        [facetCut],
        ethers.constants.AddressZero,
        '0x00',
    );

    const transaction = createSafeTransaction(treesDiamond.address, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};
export default func;

func.tags = ['config', 'config:trees-facets', 'config:add-static-tree'];
