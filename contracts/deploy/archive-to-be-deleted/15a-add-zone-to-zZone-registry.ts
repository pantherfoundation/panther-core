// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';
import {ZZonesRegistry, leafs} from '../../lib/staticTree/zZonesRegistry';

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
