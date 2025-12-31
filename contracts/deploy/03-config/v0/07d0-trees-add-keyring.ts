// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';
import {PROVIDERS_KEY} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ProvidersKeysRegistry');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    let index = 0;

    for (const numAllocKey of PROVIDERS_KEY.numAllocKeys) {
        const tx = await diamond.populateTransaction.addKeyring(
            deployer,
            numAllocKey,
        );

        const transaction = createSafeTransaction(address, tx.data!);

        await saveSafeTransaction(hre, transaction, __filename, `${index}`);
        index++;
    }
};

export default func;

func.tags = ['config', 'config:trees', 'config:add-keyring'];
