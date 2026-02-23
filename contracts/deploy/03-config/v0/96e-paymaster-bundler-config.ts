// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {PAYMASTER} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const paymasterProxy = await get('Paymaster_Proxy');
    const paymaster = await ethers.getContractAt(
        'PayMaster',
        paymasterProxy.address,
    );

    const config = {
        maxExtraGas: PAYMASTER.maxExtraGas,
        gasPriceMarkupPct: PAYMASTER.gasPriceMarkupPct,
        exchangeRiskPct: PAYMASTER.exchangeRiskPct,
        gasPriceMarkupFixed: PAYMASTER.gasPriceMarkupFixed,
    };

    const tx = await paymaster.populateTransaction.updateBundlerConfig(config);

    const transaction = createSafeTransaction(paymasterProxy.address, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};

export default func;

func.tags = ['config', 'config:paymaster', 'config:paymaster-bundler-config'];
