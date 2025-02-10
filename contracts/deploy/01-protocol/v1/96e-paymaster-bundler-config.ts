// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE, PAYMASTER} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('PayMaster_Implementation');
    const {address} = await get('Paymaster_Proxy');

    const paymaster = await ethers.getContractAt(abi, address);

    const config = {
        maxExtraGas: PAYMASTER.maxExtraGas,
        gasPriceMarkupPct: PAYMASTER.gasPriceMarkupPct,
        exchangeRiskPct: PAYMASTER.exchangeRiskPct,
    };

    const tx = await paymaster.updateBundlerConfig(config, {
        gasPrice: GAS_PRICE,
    });
    const res = await tx.wait();

    console.log('paymaster config is updated', res.transactionHash);
};

export default func;

func.tags = ['paymaster-config'];
func.dependencies = ['upgrade-paymaster-proxy'];
