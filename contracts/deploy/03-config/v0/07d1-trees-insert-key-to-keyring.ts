// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    ProvidersKeys,
    polygonLeaf,
} from '../../../lib/staticTree/providersKeys';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ProvidersKeysRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const providersKeyLeafs = Object.values(polygonLeaf);
    const providersKeyTree = new ProvidersKeys(providersKeyLeafs);

    const inputs = providersKeyTree
        .computeCommitments()
        .getInsertionInputs().providersKeyInsertionInputs;

    let index = 0;

    for (const input of inputs) {
        const {keyringId, publicKey, expiryDate, proofSiblings} = input;

        const calldata = diamond.interface.encodeFunctionData('registerKey', [
            keyringId,
            {
                x: publicKey[0].toString(),
                y: publicKey[1].toString(),
            },
            expiryDate,
            proofSiblings,
        ]);

        const transaction = createSafeTransaction(address, calldata);

        await saveSafeTransaction(hre, transaction, __filename, `${index}`);
        index++;
    }
};

export default func;

func.tags = ['config', 'config:trees', 'config:insert-key-to-keyring'];
