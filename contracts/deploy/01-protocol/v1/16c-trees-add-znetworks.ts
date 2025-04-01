// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    ZNetworksRegistry,
    testnetLeafs,
} from '../../../lib/staticTree/zNetworksRegistry';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZNetworksRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    console.log('adding znetworks');

    const zNetworkLeafs = Object.values(testnetLeafs);
    const zNetworkTree = new ZNetworksRegistry(zNetworkLeafs);
    const inputs = zNetworkTree
        .computeCommitments()
        .getInsertionInputs().zNetworkRegistryInsertionInputs;

    for (const input of inputs) {
        const {currentRoot, currentLeaf, newLeaf, leafIndex, proofSiblings} =
            input;

        const zNetworkRoot = await diamond.getZNetworksRoot();

        if (zNetworkRoot === currentRoot) {
            const tx = await diamond.addNetwork(
                currentLeaf,
                newLeaf,
                leafIndex,
                proofSiblings,
                {
                    gasPrice: GAS_PRICE,
                },
            );

            const res = await tx.wait();
            const newRoot = await diamond.getZNetworksRoot();

            console.log(
                `znetwork is added with tx hash ${res.transactionHash}, new zNetwork root is ${newRoot}`,
            );
        } else {
            console.log('The zNetworkRoot does not match the current root');
        }
    }
};
export default func;

func.tags = ['add-znetworks', 'trees', 'protocol-v1'];
func.dependencies = ['add-znetworks-registry', 'add-static-tree'];
