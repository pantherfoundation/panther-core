// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getContractEnvAddress} from '../../lib/deploymentHelpers';
import {encodePriceSqrt} from '../../lib/encodePriceSqrt';

import {FeeAmount, fetchDecimals, getTokenName} from './common/common';
import {processPairsWithParams} from './common/pairs';
import {logtTenderly} from './common/tenderly';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const zkpAddress = await getContractEnvAddress(hre, 'ZKP_TOKEN');

    const wmaticAddress = await getContractEnvAddress(hre, 'WMATIC_TOKEN');

    const linkAddress = await getContractEnvAddress(hre, 'LINK_TOKEN');

    const tokens = [zkpAddress, wmaticAddress, linkAddress];
    const amounts = ['60.0', '1.0', '0.02'];
    const currentFee = FeeAmount.MEDIUM;

    const uniswapV3MockFactoryAddress = await getContractEnvAddress(
        hre,
        'UNI_V3_FACTORY',
    );

    const factory = await ethers.getContractAt(
        'MockUniswapV3Factory',
        uniswapV3MockFactoryAddress,
    );

    await processPairsWithParams(tokens, amounts, deployPair, factory);

    async function deployPair(
        pair: [string, string],
        pairParams: [string, string],
        factory: Contract,
    ) {
        const token0 = pair[0];
        const token1 = pair[1];
        const amount0 = pairParams[0];
        const amount1 = pairParams[1];
        const tokenIN = await getTokenName(token0, ethers.provider);
        const tokenOUT = await getTokenName(token1, ethers.provider);
        const token0Decimals = await fetchDecimals(token0, ethers.provider);
        const token1Decimals = await fetchDecimals(token1, ethers.provider);
        const token0Amount = ethers.utils.parseUnits(amount0, token0Decimals);
        const token1Amount = ethers.utils.parseUnits(amount1, token1Decimals);

        console.log(
            `----------------------${factory.address}-----------------------------------------------------`,
        );
        console.log(` Creating Pool ${tokenIN} / ${tokenOUT}
         amounts ${ethers.utils.formatUnits(
             token0Amount,
             token0Decimals,
         )} / ${ethers.utils.formatUnits(token1Amount, token1Decimals)}`);

        let gasPrice = await ethers.provider.getGasPrice();
        console.log(`gasPrice =  ${gasPrice}`);
        const poolAddress = await factory.getPool(token0, token1, currentFee);
        const code = await ethers.provider.getCode(poolAddress);
        let tx;
        if (code === '0x') {
            console.log(
                `Contract not found at address ${poolAddress}. Deploying...`,
            );

            tx = await factory.createPool(token0, token1, currentFee, {
                gasPrice,
            });
            logtTenderly(tx.hash);
            await tx.wait();
        } else {
            console.log(`Contract already exists at address ${poolAddress}.`);
        }

        console.log(
            `UNI_V3_POOL_${tokenIN}_${tokenOUT}_INTERNAL_AMOY=${poolAddress}`,
        );

        const sqrtPriceX96 = encodePriceSqrt(amount0, amount1);

        const pool = await ethers.getContractAt(
            'MockUniswapV3Pool',
            poolAddress,
        );

        gasPrice = await ethers.provider.getGasPrice();
        console.log(`gasPrice =  ${gasPrice}`);

        tx = await pool.initialize(sqrtPriceX96, {
            gasPrice,
        });
        logtTenderly(tx.hash);
        await tx.wait();

        console.log(
            `UNI_V3_POOL_${tokenIN}_${tokenOUT}_INTERNAL_AMOY initialized with price ${sqrtPriceX96}`,
        );
        console.log(
            '----------------------------------------------------------------------------',
        );
    }
};

export default func;

func.tags = ['erc4337', 'uniV3-create-pairs'];

func.dependencies = ['check-params', 'deployment-consent'];
