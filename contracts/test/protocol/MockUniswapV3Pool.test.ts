// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {
    MockUniswapV3Pool,
    MockUniswapV3Factory,
    MockERC20,
} from '../../types/contracts';

describe('MockUniswapV3Pool contract', function () {
    let pool: MockUniswapV3Pool;
    let token0: MockERC20;
    let token1: MockERC20;
    let weth: FakeContract<WETH9>;
    let factory: MockUniswapV3Factory;
    let deployer: SignerWithAddress;
    let recepient: SignerWithAddress;
    let router: MockUniSwapV3Router;
    let pool1Addr: string;
    const hunderdToken = ethers.utils.parseUnits('100.0', 18);
    const ZKPForOneEther = 1;
    const WETHAmount = 1; // Token1 amount
    const ZKPAmount = ZKPForOneEther * WETHAmount; // Token0 amount
    const mockSqrtPriceLimitX96 = BigInt(
        Math.sqrt(WETHAmount / ZKPAmount) * 2 ** 96,
    );
    const fee = 500;

    before(async function () {
        [deployer, recepient] = await ethers.getSigners();

        const MockUniswapV3Factory = await ethers.getContractFactory(
            'MockUniswapV3Factory',
        );
        factory = await MockUniswapV3Factory.deploy();

        const MockERC20 = await ethers.getContractFactory('MockERC20');
        token0 = await MockERC20.deploy(0, deployer.address);
        token1 = await MockERC20.deploy(0, deployer.address);
        weth = await smock.fake('WETH9');
        router = await (
            await ethers.getContractFactory('MockUniSwapV3Router')
        ).deploy(factory.address, weth.address);

        await factory.createPool(token0.address, token1.address, fee);
        pool1Addr = await factory.getPool(token0.address, token1.address, fee);
        pool = await ethers.getContractAt('MockUniswapV3Pool', pool1Addr);
        await pool.initialize(mockSqrtPriceLimitX96);
        await token0.connect(deployer).transfer(pool1Addr, hunderdToken);
        await token1.connect(deployer).transfer(pool1Addr, hunderdToken);
    });

    describe('', () => {
        const inputAmount = ethers.utils.parseUnits('10.0', 18);
        let outputAmount;
        let currSqrtPriceX96;

        before(async function () {
            currSqrtPriceX96 = await pool.currSqrtPriceX96();
        });

        it('should slot0() ', async () => {
            const [sqrtPriceLimitX96, , , , , ,] = await pool.slot0();
            expect(sqrtPriceLimitX96).eq(mockSqrtPriceLimitX96);
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

        it('should exchange token0 to token1 ', async () => {
            // await fixture.zkpToken
            //     .connect(fixture.ethersSigner)
            //     .approve(stealthAddress, amount);
            const tx = await token1
                .connect(deployer)
                .approve(router.address, ethers.utils.parseUnits('100.0', 18));
            await tx.wait();

            const tx1 = await token0
                .connect(deployer)
                .approve(router.address, ethers.utils.parseUnits('100.0', 18));
            await tx1.wait();

            const params = {
                tokenIn: token0.address,
                tokenOut: token1.address,
                fee: fee, // Example fee tier, usually 3000 means 0.3%
                recipient: recepient.address,
                deadline: Math.floor(Date.now() / 1000) + 60 * 20, // 20 minutes from the current Unix time
                amountIn: ethers.utils.parseUnits('1.0', 18), // Example amount, 1 token with 18 decimals
                amountOutMinimum: ethers.utils.parseUnits('0.5', 18), // Example minimum amount out
                sqrtPriceLimitX96: mockSqrtPriceLimitX96,
            };

            await callExactInputSingle();

            // Call the function
            async function callExactInputSingle() {
                try {
                    const tx = await router
                        .connect(deployer)
                        .exactInputSingle(params, {});

                    console.log('Transaction hash:', tx.hash);

                    // Wait for the transaction to be confirmed
                    const receipt = await tx.wait();
                    console.log(
                        'Transaction was mined in block',
                        receipt.blockNumber,
                    );
                } catch (error) {
                    console.error('Error calling exactInputSingle:', error);
                }
            }
        });

        it('should fit MockUniswapV3Pool initCodehash', async () => {
            const artifact =
                await ethers.getContractFactory('MockUniswapV3Pool');
            const creationCode = artifact.bytecode;
            const initCodeHash = ethers.utils.keccak256(creationCode);
            expect(initCodeHash).eq(
                '0x2d1e7fb25e8434425f1e5d59e586934e690670c68b61b94f786472ef046f2d74',
            );
        });
    });
});
