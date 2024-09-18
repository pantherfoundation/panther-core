// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {ZZonesRegistry, leafs} from '../../../lib/staticTree/zZonesRegistry';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZZonesRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    console.log('adding zzones');

    const zZoneLeafs = Object.values(leafs);
    const zZoneRegistryTree = new ZZonesRegistry(zZoneLeafs);
    const inputs = zZoneRegistryTree
        .computeCommitments()
        .getInsertionInputs().zZoneRegistryInsertionInputs;

    for (const input of inputs) {
        const {currentRoot, currentLeaf, newLeaf, leafIndex, proofSiblings} =
            input;

        const tx = await diamond.addZone(
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
        const newRoot = await diamond.getZZonesRoot();

        console.log(
            `zzone is added with tx hash ${res.transactionHash}, new zZone root is ${newRoot}`,
        );
    }
};
export default func;

func.tags = ['add-zzones', 'trees', 'protocol-v1'];
func.dependencies = ['add-zzone-registry', 'add-static-tree'];
