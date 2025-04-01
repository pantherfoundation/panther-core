// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

// eslint-disable-next-line import/named
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isDev} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';
import {ProvidersKeys, testnetLeafs} from '../../lib/staticTree/providersKeys';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!isDev(hre)) return;

    const {artifacts, ethers} = hre;

    const providersKeyAddress = await getContractAddress(
        hre,
        'ProvidersKeys',
        '',
    );

    const {abi} = await artifacts.readArtifact('ProvidersKeys');
    const providersKeys = await ethers.getContractAt(abi, providersKeyAddress);

    const providersKeyLeafs = Object.values(testnetLeafs);
    const providersKeyTree = new ProvidersKeys(providersKeyLeafs);

    const inputs = providersKeyTree
        .computeCommitments()
        .getInsertionInputs().providersKeyInsertionInputs;

    console.log('root', providersKeyTree.root);

    for (const input of inputs) {
        const {keyringId, publicKey, expiryDate, proofSiblings} = input;

        const tx = await providersKeys.registerKey(
            keyringId,
            {
                x: publicKey[0].toString(),
                y: publicKey[1].toString(),
            },
            expiryDate,
            proofSiblings,
        );

        await tx.wait();
        console.log(`Provider key is registered for KeyringId ${keyringId}`);
    }
};

export default func;

func.tags = ['register-test-network-provider-key', 'forest', 'protocol'];
func.dependencies = ['providers-keys', 'add-provider'];
