// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZSwap');
    const {address} = await get('PantherPoolV1');
    const diamond = await ethers.getContractAt(abi, address);

    const uniswapV3RouterPlugin = (await get('UniswapV3RouterPlugin')).address;
    const quickswapRouterPlugin = (await get('QuickswapRouterPlugin')).address;

    let stauts = await diamond.zSwapPlugins(uniswapV3RouterPlugin);
    if (!stauts) {
        console.log('updating uniswap v3 router');
        const tx = await diamond.updatePluginStatus(
            uniswapV3RouterPlugin,
            true,
            {gasPrice: GAS_PRICE},
        );
        const res = await tx.wait();
        console.log('uniswap v3 router is updated', res.transactionHash);
    }

    stauts = await diamond.zSwapPlugins(quickswapRouterPlugin);
    if (!stauts) {
        console.log('updating quickswap v3 router');
        const tx = await diamond.updatePluginStatus(
            quickswapRouterPlugin,
            true,
            {gasPrice: GAS_PRICE},
        );
        const res = await tx.wait();
        console.log('quickswap router is updated', res.transactionHash);
    }
};
export default func;

func.tags = ['add-zswap-plugin', 'core', 'protocol-v1'];
func.dependencies = [
    'uniswap-router-plugin',
    'quickswap-router-plugin',
    'add-zswap',
];
