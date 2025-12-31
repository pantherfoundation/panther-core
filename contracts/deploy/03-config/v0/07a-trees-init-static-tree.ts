// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('StaticTree');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const tx = await diamond.populateTransaction.initializeStaticTree();

    const transaction = createSafeTransaction(address, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};

export default func;

func.tags = ['config', 'config:trees', 'config:init-static-tree'];
