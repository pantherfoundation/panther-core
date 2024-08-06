// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {MockPluginDataDecoder} from '../../types/contracts';

describe('PluginDataDecoder', function () {
    const deadline = 12345678;
    const amountOutMinimum = 1000000000000;
    const fee = 3000;
    const sqrtPriceLimitX96 = 34028236692093;

    let pluginDataDecoder: MockPluginDataDecoder;
    let token0: SignerWithAddress,
        token1: SignerWithAddress,
        plugin: SignerWithAddress,
        pool: SignerWithAddress;

    before(async function () {
        [plugin, token0, token1, pool] = await ethers.getSigners();

        const PluginDataDecoder = await ethers.getContractFactory(
            'MockPluginDataDecoder',
        );
        pluginDataDecoder =
            (await PluginDataDecoder.deploy()) as MockPluginDataDecoder;
    });

    it('should extract plugin address', async function () {
        const data = ethers.utils.solidityPack(['address'], [plugin.address]);

        const extractedAddress =
            await pluginDataDecoder.testExtractPluginAddress(data);
        expect(extractedAddress).to.equal(plugin.address);
    });

    it('should decode UniswapV3RouterExactInputSingleData', async function () {
        const data = ethers.utils.solidityPack(
            ['address', 'uint32', 'uint96', 'uint24', 'uint160'],
            [
                plugin.address,
                deadline,
                amountOutMinimum,
                fee,
                sqrtPriceLimitX96,
            ],
        );

        const result =
            await pluginDataDecoder.testDecodeUniswapV3RouterExactInputSingleData(
                data,
            );
        expect(result.deadline).to.equal(deadline);
        expect(result.amountOutMinimum).to.equal(amountOutMinimum);
        expect(result.fee).to.equal(fee);
        expect(result.sqrtPriceLimitX96).to.equal(sqrtPriceLimitX96);
    });

    it('should decode testDecodeUniswapV3PoolData', async function () {
        const data = ethers.utils.solidityPack(
            ['address', 'address', 'uint160'],
            [plugin.address, pool.address, sqrtPriceLimitX96],
        );

        const result =
            await pluginDataDecoder.testDecodeUniswapV3PoolData(data);

        expect(result.poolAddress).to.equal(pool.address);
        expect(result.sqrtPriceLimitX96).to.equal(sqrtPriceLimitX96);
    });

    it('should decode UniswapV3RouterExactInputData', async function () {
        const path = ethers.utils.hexConcat([
            ethers.utils.solidityPack(['address'], [token0.address]),
            ethers.utils.solidityPack(['address'], [token1.address]),
        ]);

        const data = ethers.utils.hexConcat([
            ethers.utils.solidityPack(
                ['address', 'uint32', 'uint96'],
                [plugin.address, deadline, amountOutMinimum],
            ),
            path,
        ]);

        const result =
            await pluginDataDecoder.testDecodeUniswapV3RouterExactInputData(
                data,
            );
        expect(result.deadline).to.equal(deadline);
        expect(result.amountOutMinimum).to.equal(amountOutMinimum);
        expect(result.path).to.equal(path);
    });

    it('should decode QuickswapRouterExactInputSingleData', async function () {
        const data = ethers.utils.solidityPack(
            ['address', 'uint96', 'uint32'],
            [plugin.address, amountOutMinimum, deadline],
        );

        const result =
            await pluginDataDecoder.testDecodeQuickswapRouterExactInputSingleData(
                data,
            );

        expect(result.amountOutMin).to.equal(amountOutMinimum);
        expect(result.deadline).to.equal(deadline);
    });

    it('should decode QuickswapRouterExactInputData', async function () {
        const path = [token0.address, token1.address];

        const data = ethers.utils.hexConcat([
            ethers.utils.solidityPack(
                ['address', 'uint96', 'uint32'],
                [plugin.address, amountOutMinimum, deadline],
            ),
            ethers.utils.solidityPack(['address', 'address'], path),
        ]);

        const result =
            await pluginDataDecoder.testDecodeQuickswapRouterExactInputData(
                data,
            );
        expect(result.amountOutMin).to.equal(amountOutMinimum);
        expect(result.deadline).to.equal(deadline);
        expect(result.path).to.deep.equal(path);
    });

    it('should revert for invalid length of data', async function () {
        const invalidData = ethers.utils.solidityPack(
            ['address', 'uint96'],
            [plugin.address, amountOutMinimum],
        );

        await expect(
            pluginDataDecoder.testDecodeUniswapV3RouterExactInputSingleData(
                invalidData,
            ),
        ).to.be.revertedWith('invalid length');

        await expect(
            pluginDataDecoder.testDecodeUniswapV3RouterExactInputData(
                invalidData,
            ),
        ).to.be.revertedWith('invalid length');

        await expect(
            pluginDataDecoder.testDecodeUniswapV3PoolData(invalidData),
        ).to.be.revertedWith('invalid Length');

        await expect(
            pluginDataDecoder.testDecodeQuickswapRouterExactInputSingleData(
                invalidData,
            ),
        ).to.be.revertedWith('invalid Length');
    });
});
