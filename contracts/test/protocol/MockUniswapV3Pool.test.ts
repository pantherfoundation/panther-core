// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {MockUniswapV3Pool, MockUniswapV3Factory} from '../../types/contracts';

describe('UniswapV3Pair contract', function () {
    let pool: MockUniswapV3Pool;
    let token0: FakeContract<IERC20>;
    let token1: FakeContract<IERC20>;
    let factory: MockUniswapV3Factory;
    let deployer: SignerWithAddress;
    let pool1Addr: string;
    const oneToken = ethers.constants.WeiPerEther;
    const ZKPForOneEther = 33;
    const WETHAmount = 1; // Token1 amount
    const ZKPAmount = ZKPForOneEther * WETHAmount; // Token0 amount
    const mockSqrtPriceLimitX96 = BigInt(
        Math.sqrt(WETHAmount / ZKPAmount) * 2 ** 96,
    );
    const fee = 500;

    before(async function () {
        [deployer] = await ethers.getSigners();
        const MockUniswapV3Factory = await ethers.getContractFactory(
            'MockUniswapV3Factory',
        );
        factory = await MockUniswapV3Factory.deploy(await deployer.address);
        token0 = await smock.fake('IERC20');
        token1 = await smock.fake('IERC20');
        token0.transfer.returns(true);
        token1.transfer.returns(true);
        await factory.createPool(token0.address, token1.address, fee);
        pool1Addr = await factory.getPool(token0.address, token1.address, fee);
        pool = await ethers.getContractAt('MockUniswapV3Pool', pool1Addr);
        await pool.initialize(mockSqrtPriceLimitX96);
        await token0.connect(deployer).transfer(pool1Addr, oneToken);
        await token1.connect(deployer).transfer(pool1Addr, oneToken);
    });

    describe('', () => {
        const inputAmount = oneToken;
        let outputAmount;
        let currSqrtPriceX96;

        before(async function () {
            currSqrtPriceX96 = await pool.currSqrtPriceX96();
        });

        it('should slot0() ', async () => {
            const [sqrtPriceLimitX96, , , , , ,] = await pool.slot0();
            expect(sqrtPriceLimitX96).eq(mockSqrtPriceLimitX96);
        });

        it('should exchange token0 to token1 ', async () => {
            outputAmount = await pool.getQuoteAmount(false, inputAmount, 3500);
            expect(outputAmount).to.be.closeTo(
                inputAmount.mul(ZKPForOneEther),
                1e15,
            );
        });

        it('should exchange token1 to token1 ', async () => {
            outputAmount = await pool.getQuoteAmount(true, inputAmount, 3600);
            expect(outputAmount).to.be.closeTo(
                inputAmount.div(ZKPForOneEther),
                1e12,
            );
        });

        it('getOutputAmount should match ', async () => {
            let out1;
            [out1, outputAmount] = await pool.calculateAmount(
                true,
                currSqrtPriceX96,
                inputAmount,
            );
            expect(outputAmount).to.be.closeTo(
                inputAmount.div(ZKPForOneEther),
                10,
            );
            expect(inputAmount).eq(out1);
        });

        it('getOutputAmount should match ', async () => {
            let out1;
            [out1, outputAmount] = await pool.calculateAmount(
                false,
                currSqrtPriceX96,
                inputAmount,
            );
            expect(out1).to.be.closeTo(inputAmount.mul(ZKPForOneEther), 10000);
            expect(inputAmount).eq(outputAmount);
        });
    });
});
