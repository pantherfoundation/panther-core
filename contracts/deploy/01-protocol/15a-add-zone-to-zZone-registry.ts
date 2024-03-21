// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {ZZonesRegistry, leafs} from '../../lib/data/staticTree/zZonesRegistry';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const zZoneRegistryAddress = await getContractAddress(
        hre,
        'ZZonesRegistry',
        '',
    );

    const {abi} = await artifacts.readArtifact('ZZonesRegistry');
    const zZonesRegistry = await ethers.getContractAt(
        abi,
        zZoneRegistryAddress,
    );

    const zZoneLeafs = Object.values(leafs);
    const zZoneRegistryTree = new ZZonesRegistry(zZoneLeafs);
    const inputs = zZoneRegistryTree
        .computeCommitments()
        .getInsertionInputs().zZoneRegistryInsertionInputs;

    for (const input of inputs) {
        const {currentRoot, currentLeaf, newLeaf, leafIndex, proofSiblings} =
            input;

        const tx = await zZonesRegistry.addZone(
            currentRoot,
            currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings,
        );

        await tx.wait();

        const newRoot = await zZonesRegistry.getRoot();
        console.log(
            `Zone is added to zZoneRegistry. new zZone tree root is ${newRoot}`,
        );
    }
};
export default func;

func.tags = ['add-zone', 'forest', 'protocol'];
func.dependencies = ['z-zones-registry'];
