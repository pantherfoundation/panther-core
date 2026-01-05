// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';
import {FEE_MASTER} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const feeMasterProxy = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(
        'FeeMaster',
        feeMasterProxy.address,
    );

    // Get ZKP token contract using the same pattern as the example
    const zkpToken = await ethers.getContractAt('MockPZkp', pzkp);

    // First transaction: Transfer ZKP tokens from Safe to FeeMaster
    const transferTx = await zkpToken.populateTransaction.transfer(
        feeMasterProxy.address,
        FEE_MASTER.zkpTokenReserves.toString(),
    );

    const transferTransaction = createSafeTransaction(pzkp, transferTx.data!);

    // Second transaction: Increase ZKP token donations in FeeMaster
    const increaseTx =
        await feeMaster.populateTransaction.increaseZkpTokenDonations(
            FEE_MASTER.zkpTokenReserves.toString(),
        );

    const increaseTransaction = createSafeTransaction(
        feeMasterProxy.address,
        increaseTx.data!,
    );

    // Save both transactions with suffixes to ensure proper ordering
    await saveSafeTransaction(
        hre,
        transferTransaction,
        __filename,
        'a-transfer',
    );
    await saveSafeTransaction(
        hre,
        increaseTransaction,
        __filename,
        'b-increase',
    );
};

export default func;

func.tags = ['config', 'config:fee-master', 'config:transfer-zkp-donation'];
