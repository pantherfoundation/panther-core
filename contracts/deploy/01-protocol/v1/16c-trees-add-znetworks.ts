// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    ZNetworksRegistry,
    testnetLeafs,
} from '../../../lib/staticTree/zNetworksRegistry';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZNetworksRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    console.log('adding znetworks');

    const zZoneLeafs = Object.values(testnetLeafs);
    const zZoneRegistryTree = new ZNetworksRegistry(zZoneLeafs);
    const inputs = zZoneRegistryTree
        .computeCommitments()
        .getInsertionInputs().zNetworkRegistryInsertionInputs;

    for (const input of inputs) {
        const {currentRoot, currentLeaf, newLeaf, leafIndex, proofSiblings} =
            input;

        const tx = await diamond.addNetwork(
            currentRoot,
            currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings,
            {
                gasPrice: 30000000000,
            },
        );

        const res = await tx.wait();
        const newRoot = await diamond.getStaticRoot();

        console.log(
            `znetwork is added with tx hash ${res.transactionHash}, new zNetwork root is ${newRoot}`,
        );
    }
};
export default func;

func.tags = ['add-znetworks', 'trees', 'protocol-v1'];
func.dependencies = ['add-znetworks-registry', 'add-static-tree'];
