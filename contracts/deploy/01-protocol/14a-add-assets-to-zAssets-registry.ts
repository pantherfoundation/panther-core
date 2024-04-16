// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';
import {ZAssetsRegistry, leafs} from '../../lib/staticTree/zAssetsRegistry';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const zAssetsRegistryAddress = await getContractAddress(
        hre,
        'ZAssetsRegistryV1',
        '',
    );

    const {abi} = await artifacts.readArtifact('ZAssetsRegistryV1');
    const zAssetsRegistry = await ethers.getContractAt(
        abi,
        zAssetsRegistryAddress,
    );

    const zAssetLeafs = Object.values(leafs);
    const zAssetRegistryTree = new ZAssetsRegistry(zAssetLeafs);
    const inputs = zAssetRegistryTree
        .computeCommitments()
        .getInsertionInputs().zAssetRegistryInsertionInputs;

    for (const input of inputs) {
        const {currentRoot, currentLeaf, newLeaf, leafIndex, proofSiblings} =
            input;

        const tx = await zAssetsRegistry.addZAsset(
            currentRoot,
            currentLeaf,
            newLeaf,
            leafIndex,
            proofSiblings,
        );

        await tx.wait();

        const newRoot = await zAssetsRegistry.getRoot();
        console.log(
            `Asset is added to zAssetsRegistry. new zAsset tree root is ${newRoot}`,
        );
    }
};
export default func;

func.tags = ['add-asset', 'forest', 'protocol'];
func.dependencies = ['z-assets-registry'];
