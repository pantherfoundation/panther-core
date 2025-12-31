// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {FEE_MASTER} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

export interface DonationParams {
    txTypes: string[];
    donateAmounts: string[];
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const feeMasterProxy = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(
        'FeeMaster',
        feeMasterProxy.address,
    );

    const tx = await feeMaster.populateTransaction.updateDonations(
        FEE_MASTER.txTypes,
        FEE_MASTER.donateAmounts.map(a => a.toString()),
    );

    const transaction = createSafeTransaction(feeMasterProxy.address, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};
export default func;

func.tags = ['config', 'config:fee-master', 'config:update-zkp-donation'];
