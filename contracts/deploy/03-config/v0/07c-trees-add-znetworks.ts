// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    ZNetworksRegistry,
    polygonLeaf,
} from '../../../lib/staticTree/zNetworksRegistry';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZNetworksRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const zNetworkLeafs = Object.values(polygonLeaf);
    const zNetworkTree = new ZNetworksRegistry(zNetworkLeafs);
    const inputs = zNetworkTree
        .computeCommitments()
        .getInsertionInputs().zNetworkRegistryInsertionInputs;

    let index = 0;

    for (const input of inputs) {
        const {currentLeaf, newLeaf, leafIndex, proofSiblings} = input;

        const tx = await diamond.populateTransaction.addNetwork(
            currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings,
        );

        const transaction = createSafeTransaction(address, tx.data!);

        await saveSafeTransaction(hre, transaction, __filename, `${index}`);
        index++;
    }
};
export default func;

func.tags = ['config', 'config:trees', 'config:add-znetworks'];
