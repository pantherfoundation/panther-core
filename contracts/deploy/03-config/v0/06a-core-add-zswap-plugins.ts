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

    const pantherPoolV1 = await get('PantherPoolV1');
    const diamond = await ethers.getContractAt('ZSwap', pantherPoolV1.address);

    const uniswapV3RouterPlugin = (await get('UniswapV3RouterPlugin')).address;
    const quickswapRouterPlugin = (await get('QuickswapRouterPlugin')).address;

    // Generate transaction for uniswap v3 router
    const uniswapTx = await diamond.populateTransaction.updatePluginStatus(
        uniswapV3RouterPlugin,
        true,
    );
    const uniswapTransaction = createSafeTransaction(
        pantherPoolV1.address,
        uniswapTx.data!,
    );
    await saveSafeTransaction(hre, uniswapTransaction, __filename, 'uniswap');

    // Generate transaction for quickswap router
    const quickswapTx = await diamond.populateTransaction.updatePluginStatus(
        quickswapRouterPlugin,
        true,
    );
    const quickswapTransaction = createSafeTransaction(
        pantherPoolV1.address,
        quickswapTx.data!,
    );
    await saveSafeTransaction(
        hre,
        quickswapTransaction,
        __filename,
        'quickswap',
    );
};
export default func;

func.tags = ['config', 'config:core', 'config:add-zswap-plugins'];
