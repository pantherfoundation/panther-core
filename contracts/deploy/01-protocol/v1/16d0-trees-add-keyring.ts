// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ProvidersKeysRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const numAllocKeys = [20, 50];

    console.log('Adding keyrings...');

    const transactions = numAllocKeys.map(async numAllocKeys => {
        const tx = await diamond.addKeyring(deployer, numAllocKeys, {
            gasPrice: 30000000000,
        });
        return tx.wait();
    });

    transactions.forEach((tx, index) => {
        const allocKeys = numAllocKeys[index];
        console.log(
            `Keyring added for operator ${deployer} with ${allocKeys} allocated keys. Transaction hash: ${tx.transactionHash}`,
        );
    });
};

export default func;

func.tags = ['add-keyring', 'trees', 'protocol-v1'];
func.dependencies = ['add-providers-keys-registry', 'add-static-tree'];
