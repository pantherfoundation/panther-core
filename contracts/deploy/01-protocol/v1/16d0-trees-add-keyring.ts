// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE, PROVIDERS_KEY} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ProvidersKeysRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    console.log('Adding keyrings...');

    for (const numAllocKey of PROVIDERS_KEY.numAllocKeys) {
        const tx = await diamond.addKeyring(deployer, numAllocKey, {
            gasPrice: GAS_PRICE,
        });
        const res = await tx.wait();

        console.log(
            `Keyring added for operator ${deployer} with ${numAllocKey} allocated keys. Transaction hash: ${res.transactionHash}`,
        );
    }
};

export default func;

func.tags = ['add-keyring', 'trees', 'protocol-v1'];
func.dependencies = ['add-providers-keys-registry'];
