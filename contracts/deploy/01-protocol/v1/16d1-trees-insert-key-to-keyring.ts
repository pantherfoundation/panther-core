// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

// eslint-disable-next-line import/named
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    ProvidersKeys,
    testnetLeafs,
} from '../../../lib/staticTree/providersKeys';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ProvidersKeysRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const providersKeyLeafs = Object.values(testnetLeafs);
    const providersKeyTree = new ProvidersKeys(providersKeyLeafs);

    const inputs = providersKeyTree
        .computeCommitments()
        .getInsertionInputs().providersKeyInsertionInputs;

    for (const input of inputs) {
        const {keyringId, publicKey, expiryDate, proofSiblings} = input;

        const tx = await diamond.registerKey(
            keyringId,
            {
                x: publicKey[0].toString(),
                y: publicKey[1].toString(),
            },
            expiryDate,
            proofSiblings,
            {
                gasPrice: GAS_PRICE,
            },
        );

        const res = await tx.wait();

        const newRoot = await diamond.getProvidersKeysRoot();
        console.log(
            `Provider key is registered with tx hash ${res.transactionHash}, new ProvidersKeysRegistry root is ${newRoot}`,
        );
    }
};

export default func;

func.tags = ['insert-key-to-keyring', 'trees', 'protocol-v1'];
