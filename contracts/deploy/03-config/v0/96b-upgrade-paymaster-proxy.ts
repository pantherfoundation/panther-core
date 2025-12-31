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

    const paymasterProxy = await get('Paymaster_Proxy');
    const paymasterImp = await get('PayMaster_Implementation');

    const proxy = await ethers.getContractAt(
        'EIP173ProxyWithReceive',
        paymasterProxy.address,
    );

    const tx = await proxy.populateTransaction.upgradeTo(paymasterImp.address);

    const transaction = createSafeTransaction(paymasterProxy.address, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};
export default func;

func.tags = ['config', 'config:paymaster', 'config:upgrade-paymaster-proxy'];
