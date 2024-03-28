// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isDev} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';
import {
    ZNetworksRegistry,
    localLeafs,
} from '../../lib/staticTree/zNetworksRegistry';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!isDev(hre)) return;

    const {artifacts, ethers} = hre;

    const zNetworkRegistryAddress = await getContractAddress(
        hre,
        'ZNetworksRegistry',
        '',
    );

    const {abi} = await artifacts.readArtifact('ZNetworksRegistry');
    const zNetworkRegistry = await ethers.getContractAt(
        abi,
        zNetworkRegistryAddress,
    );

    const zNetworkLeafs = Object.values(localLeafs);
    const zNetworkRegistryTree = new ZNetworksRegistry(zNetworkLeafs);
    const inputs = zNetworkRegistryTree
        .computeCommitments()
        .getInsertionInputs().zNetworkRegistryInsertionInputs;

    const root = zNetworkRegistryTree.root;

    console.dir({inputs, root}, {depth: null});

    for (const input of inputs) {
        const {currentRoot, currentLeaf, newLeaf, leafIndex, proofSiblings} =
            input;

        const tx = await zNetworkRegistry.addNetwork(
            currentRoot,
            currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings,
        );

        await tx.wait();

        const newRoot = await zNetworkRegistry.getRoot();
        console.log(
            `Network is added to zNetworkRegistry. new zNetwork tree root is ${newRoot}`,
        );
    }
};
export default func;

func.tags = ['add-network-id', 'forest', 'protocol'];
func.dependencies = ['z-networks-registry'];
