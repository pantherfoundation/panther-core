// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {ZAssetsRegistry, leafs} from '../../../lib/staticTree/zAssetsRegistry';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZAssetsRegistryV1');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    console.log('adding zAssets');

    const zAssetsLeafs = leafs('canary');
    const zAssetsTree = new ZAssetsRegistry(zAssetsLeafs);
    const inputs = zAssetsTree
        .computeCommitments()
        .getInsertionInputs().zAssetRegistryInsertionInputs;

    for (let index = 0; index < inputs.length; index++) {
        const input = inputs[index];
        const {zAssetRegistryParams, weight, proofSiblings} = input;

        const tx = await diamond.addZAsset(
            zAssetRegistryParams[index],
            weight,
            proofSiblings,
            {
                gasPrice: GAS_PRICE,
            },
        );

        const res = await tx.wait();
        const newRoot = await diamond.getZAssetsRoot();

        console.log(
            `zAsset is added with tx hash ${res.transactionHash}, new zAsset root is ${newRoot}`,
        );
    }
};
export default func;

func.tags = ['add-zassets', 'trees', 'protocol-v1'];
func.dependencies = ['add-zassets-registry', 'add-static-tree'];
