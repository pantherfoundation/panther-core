// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// eslint-disable-next-line import/named
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    ProvidersKeys,
    testnetLeafs,
} from '../../../lib/staticTree/providersKeys';

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
                gasPrice: 30000000000,
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
