// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isDev} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';
import {
    ZNetworksRegistry,
    testnetLeafs,
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

    const zNetworkLeafs = Object.values(testnetLeafs);
    const zNetworkRegistryTree = new ZNetworksRegistry(zNetworkLeafs);
    const inputs = zNetworkRegistryTree
        .computeCommitments()
        .getInsertionInputs().zNetworkRegistryInsertionInputs;

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

func.tags = ['add-test-network-id', 'forest', 'protocol'];
func.dependencies = ['z-networks-registry'];
