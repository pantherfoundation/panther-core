// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress, getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const deployer = await getNamedAccount(hre, 'deployer');
    const {artifacts, ethers} = hre;

    const providersKeyAddress = await getContractAddress(
        hre,
        'ProvidersKeys',
        '',
    );
    const {abi} = await artifacts.readArtifact('ProvidersKeys');
    const providersKeys = await ethers.getContractAt(abi, providersKeyAddress);

    const numAllocKeys = [20, 50];
    const transactions = await Promise.all(
        numAllocKeys.map(async numAllocKeys => {
            const tx = await providersKeys.addKeyring(deployer, numAllocKeys);
            return tx.wait();
        }),
    );

    transactions.forEach((tx, index) => {
        const allocKeys = numAllocKeys[index];
        console.log(
            `Keyring added for operator ${deployer} with ${allocKeys} allocated keys. Transaction hash: ${tx.transactionHash}`,
        );
    });
};

export default func;

func.tags = ['add-provider', 'forest', 'protocol'];
func.dependencies = ['providers-keys'];
