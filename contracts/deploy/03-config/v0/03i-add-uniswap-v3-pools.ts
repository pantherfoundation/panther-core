// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pZkp = await getNamedAccount(hre, 'pzkp');
    const link = await getNamedAccount(hre, 'link');
    const weth9 = await getNamedAccount(hre, 'weth9');
    const pZkpNativePool = await getNamedAccount(
        hre,
        'pZkp_native_uniswapV3Pool',
    );
    const pZkpLinkPool = await getNamedAccount(hre, 'pZkp_link_uniswapV3Pool');
    const linkNativePool = await getNamedAccount(
        hre,
        'link_native_uniswapV3Pool',
    );

    const {
        deployments: {get},
        ethers,
    } = hre;

    const {address} = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt('FeeMaster', address);

    // Helper function to order tokens by address (Uniswap V3 requirement)
    const orderTokens = (tokenA: string, tokenB: string) => {
        return tokenA.toLowerCase() < tokenB.toLowerCase()
            ? [tokenA, tokenB]
            : [tokenB, tokenA];
    };

    // Generate calldata for each pool
    const [pzkpNativeToken0, pzkpNativeToken1] = orderTokens(weth9, pZkp);
    const [pzkpLinkToken0, pzkpLinkToken1] = orderTokens(link, pZkp);
    const [linkNativeToken0, linkNativeToken1] = orderTokens(weth9, link);

    const pools = [
        {
            name: 'pzkp-native',
            pool: pZkpNativePool,
            token0: pzkpNativeToken0,
            token1: pzkpNativeToken1,
            enabled: true,
        },
        {
            name: 'pzkp-link',
            pool: pZkpLinkPool,
            token0: pzkpLinkToken0,
            token1: pzkpLinkToken1,
            enabled: true,
        },
        {
            name: 'link-native',
            pool: linkNativePool,
            token0: linkNativeToken0,
            token1: linkNativeToken1,
            enabled: true,
        },
    ];

    for (const poolConfig of pools) {
        const tx = await feeMaster.populateTransaction.updatePool(
            poolConfig.pool,
            poolConfig.token0,
            poolConfig.token1,
            poolConfig.enabled,
        );

        const transaction = createSafeTransaction(address, tx.data!);

        await saveSafeTransaction(
            hre,
            transaction,
            __filename,
            poolConfig.name,
        );
    }
};

export default func;

func.tags = ['config', 'config:fee-master', 'config:add-uniswap-v3-pools'];
