// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {ZAssetsRegistry, leafs} from '../../../lib/staticTree/zAssetsRegistry';
import {decodeTokenTypeAndAddress} from '../../../lib/token';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
        network,
    } = hre;

    const {abi} = await get('ZAssetsRegistryV1');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const zAssetsLeafs = leafs(network.name.toLowerCase());
    const zAssetsTree = new ZAssetsRegistry(zAssetsLeafs);
    const inputs = zAssetsTree
        .computeCommitments()
        .getInsertionInputs().zAssetRegistryInsertionInputs;

    for (let index = 0; index < inputs.length; index++) {
        const input = inputs[index];
        const {zAssetRegistryParams, weight, proofSiblings} = input;

        const leaf = zAssetsLeafs[index];
        const {type: tokenType} = decodeTokenTypeAndAddress(
            leaf.tokenAddrAndType,
        );

        const correctedParams = {
            ...zAssetRegistryParams[index],
            tokenType: tokenType,
        };

        const jsonReplacer = (_key: string, value: unknown) =>
            typeof value === 'bigint' ? value.toString() : value;

        console.log(
            JSON.stringify(
                {
                    index,
                    params: correctedParams,
                    weight: weight.toString(),
                    proof: proofSiblings,
                },
                jsonReplacer,
                2,
            ),
        );

        const tx = await diamond.populateTransaction.addZAsset(
            correctedParams,
            weight,
            proofSiblings,
        );

        const transaction = createSafeTransaction(address, tx.data!);

        await saveSafeTransaction(hre, transaction, __filename, `${index}`);
    }
};
export default func;

func.tags = ['config', 'config:trees', 'config:add-zassets'];
