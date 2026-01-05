// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';
import {zkpAmount, prpVirtualAmount} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

// NB: Do ZKP transfer before executing this script!
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const pantherPoolV1 = await get('PantherPoolV1');
    const prpConversion = await ethers.getContractAt(
        'PrpConversion',
        pantherPoolV1.address,
    );

    // Generate transaction for transferring zkp tokens
    const pZkp = await ethers.getContractAt('MockPZkp', pzkp);
    const transferTx = await pZkp.populateTransaction.transfer(
        pantherPoolV1.address,
        zkpAmount.toString(),
    );
    const transferTransaction = createSafeTransaction(pzkp, transferTx.data!);
    await saveSafeTransaction(
        hre,
        transferTransaction,
        __filename,
        'a-transfer',
    );

    // Generate transaction for initializing prpConversion
    const initTx = await prpConversion.populateTransaction.initPool(
        prpVirtualAmount.toString(),
        zkpAmount.toString(),
    );
    const initTransaction = createSafeTransaction(
        pantherPoolV1.address,
        initTx.data!,
    );
    await saveSafeTransaction(hre, initTransaction, __filename, 'b-init');
};
export default func;

func.tags = ['config', 'config:core', 'config:init-prp-conversion'];
