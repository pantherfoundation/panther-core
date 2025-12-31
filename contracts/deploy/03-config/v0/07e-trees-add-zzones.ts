// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {ZZonesRegistry, leafs} from '../../../lib/staticTree/zZonesRegistry';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZZonesRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const zZoneLeafs = Object.values(leafs);
    const zZoneRegistryTree = new ZZonesRegistry(zZoneLeafs);
    const inputs = zZoneRegistryTree
        .computeCommitments()
        .getInsertionInputs().zZoneRegistryInsertionInputs;

    let index = 0;

    for (const input of inputs) {
        const {currentLeaf, newLeaf, leafIndex, proofSiblings} = input;

        const calldata = diamond.interface.encodeFunctionData('addZone', [
            currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings,
        ]);

        const transaction = createSafeTransaction(address, calldata);

        await saveSafeTransaction(hre, transaction, __filename, `${index}`);
        index++;
    }
};
export default func;

func.tags = ['config', 'config:trees', 'config:add-zzones'];
