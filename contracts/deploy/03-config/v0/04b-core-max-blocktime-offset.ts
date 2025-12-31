// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {maxBlocktimeOffset} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const pantherPoolV1 = await get('PantherPoolV1');
    const diamond = await ethers.getContractAt(
        'AppConfiguration',
        pantherPoolV1.address,
    );

    const tx = await diamond.populateTransaction.updateMaxBlockTimeOffset(
        parseInt(maxBlocktimeOffset),
    );

    const transaction = createSafeTransaction(pantherPoolV1.address, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};
export default func;

func.tags = ['config', 'config:core', 'config:update-max-blocktime-offset'];
