// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// eslint-disable-next-line import/named
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';
import {ProvidersKeys} from '../../lib/staticTree/providerskeys';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const providersKeyAddress = await getContractAddress(
        hre,
        'ProvidersKeys',
        '',
    );

    const {abi} = await artifacts.readArtifact('ProvidersKeys');
    const providersKeys = await ethers.getContractAt(abi, providersKeyAddress);

    const inputs = ProvidersKeys();

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

func.tags = ['register-provider-key', 'forest', 'protocol'];
func.dependencies = ['providers-keys', 'add-provider'];
