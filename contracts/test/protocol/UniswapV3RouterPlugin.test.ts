// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock} from '@defi-wonderland/smock';
import chai, {expect} from 'chai';
import {Contract} from 'ethers';
import {ethers} from 'hardhat';

import {generateExactInputSingleData} from '../../lib/pluginData';
import {TokenType} from '../../lib/token';
import {MockERC20} from '../../types/contracts';

import {getBlockTimestamp} from './helpers/hardhat';

chai.use(smock.matchers);

const one = ethers.utils.parseEther('1');

describe('UniswapV3RouterPlugin', function () {
    let plugin: Contract;
    let owner: any;
    let uniswapRouter: any;
    let uniswapQuoterV2: any;
    let weth9: any;
    let token0: MockERC20;
    let token1: MockERC20;
    let vault: string;
    let fee: number;
    let deadline: number;

    async function setupFixture() {
        fee = 3000;
        deadline = (await getBlockTimestamp()) + 86400;

        [owner] = await ethers.getSigners();

        const MockERC20 = await ethers.getContractFactory('MockERC20');

        token0 = await MockERC20.deploy(0, owner.address);
        await token0.deployed();

        token1 = await MockERC20.deploy(0, owner.address);
        await token1.deployed();

        vault = owner.address;

        uniswapRouter = await smock.fake('ISwapRouter');
        uniswapQuoterV2 = await smock.fake('IQuoterV2');
        weth9 = await smock.fake('IWETH');
        weth9.approve.returns(true);

        const UniswapV3RouterPluginFactory = await ethers.getContractFactory(
            'UniswapV3RouterPlugin',
        );
        plugin = await UniswapV3RouterPluginFactory.deploy(
            uniswapRouter.address,
            uniswapQuoterV2.address,
            vault,
        );
        await plugin.deployed();
    }

    context('Direct Pair Scenarios', () => {
        const amountIn = one;

        before(async function () {
            await setupFixture();
        });

        it('should deploy the contract with the correct addresses', async function () {
            expect(await plugin.UNISWAP_ROUTER()).to.equal(
                uniswapRouter.address,
            );
            expect(await plugin.UNISWAP_QUOTERV2()).to.equal(
                uniswapQuoterV2.address,
            );
            expect(await plugin.VAULT()).to.equal(vault);
        });

        it('should handle quoteExactInputSingle function calls', async function () {
            const tokenInAddress = token0.address;
            const tokenOutAddress = token1.address;

            uniswapQuoterV2.quoteExactInputSingle.returns([amountIn, 0, 0, 0]);

            const quotes = await plugin.callStatic.quoteExactInputSingle(
                tokenOutAddress,
                tokenInAddress,
                amountIn,
            );

            expect(Array.isArray(quotes)).to.be.true;
        });

        it('should execute swap', async function () {
            const pluginData = generateExactInputSingleData(
                token0.address,
                BigInt(0),
                token1.address,
                0,
                plugin.address,
                0,
            );

            expect(pluginData.data.length).eq(
                120,
                'wrong UNISWAPV3_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH',
            );

            await plugin.execute(pluginData);

            expect(uniswapRouter.exactInputSingle).to.have.been.called;

            // Assertions for all parameters
            expect(
                uniswapRouter.exactInputSingle.getCall(0).args[0].tokenIn,
            ).to.eq(token0.address);
            expect(
                uniswapRouter.exactInputSingle.getCall(0).args[0].tokenOut,
            ).to.eq(token1.address);
            expect(uniswapRouter.exactInputSingle.getCall(0).args[0].fee).to.eq(
                0,
            );
            expect(
                uniswapRouter.exactInputSingle.getCall(0).args[0].recipient,
            ).to.eq(vault);
            expect(
                uniswapRouter.exactInputSingle.getCall(0).args[0].deadline,
            ).to.eq(0);
            expect(
                uniswapRouter.exactInputSingle.getCall(0).args[0].amountIn,
            ).to.eq(0);
            expect(
                uniswapRouter.exactInputSingle.getCall(0).args[0]
                    .amountOutMinimum,
            ).to.eq(0);
            expect(
                uniswapRouter.exactInputSingle.getCall(0).args[0]
                    .sqrtPriceLimitX96,
            ).to.eq(0);
        });

        // TODO multihop swaps are not supported in this version
        context.skip('No Direct Pair Scenarios', () => {
            beforeEach(async function () {
                await setupFixture();
            });

            it('should return non zero amountOut if at least one feeTier exists', async function () {
                uniswapQuoterV2.quoteExactInputSingle.returns([one, 0, 0, 0]);

                const [path, amountOut] =
                    await plugin.callStatic.quoteExactInput(
                        token0.address,
                        token1.address,
                        one,
                    );

                expect(path).to.not.be.empty;
                expect(amountOut).to.be.gt(0);
            });

            it('should quote exact input with WETH as tokenIn', async function () {
                uniswapQuoterV2.quoteExactInputSingle.returns([one, 0, 0, 0]);

                const [path, amountOut] =
                    await plugin.callStatic.quoteExactInput(
                        token0.address,
                        token1.address,
                        one,
                    );

                expect(path).to.not.be.empty;
                expect(amountOut).to.be.gt(0);
            });

            it('should execute a multi-hop swap via exactInput', async function () {
                const amountIn = one;
                uniswapQuoterV2.quoteExactInputSingle.returns([one, 0, 0, 0]);

                const [path, amountOut] =
                    await plugin.callStatic.quoteExactInput(
                        token0.address,
                        token1.address,
                        amountIn,
                    );

                const encodedData = ethers.utils.solidityPack(
                    ['address', 'uint32', 'uint96', 'bytes'],
                    [plugin.address, deadline, amountOut, path],
                );

                await token0.transfer(plugin.address, amountIn);

                uniswapRouter.exactInput.returns(amountOut);

                await plugin.execute({
                    tokenIn: token0.address,
                    amountIn: amountIn,
                    tokenOut: token1.address,
                    tokenType: TokenType.Erc20,
                    data: encodedData,
                });

                const exactInputSingleParams = {
                    tokenIn: token0.address,
                    tokenOut: token1.address,
                    fee: fee,
                    recipient: vault,
                    sqrtPriceLimitX96: 0,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                };

                expect(uniswapRouter.exactInputSingle).to.have.been.calledWith(
                    JSON.stringify(exactInputSingleParams),
                );
            });
        });

        context('Native Token Scenarios', () => {
            beforeEach(async function () {
                await setupFixture();
            });

            it('should withdraw ETH in exchange for ERC20', async function () {
                const pluginData = generateExactInputSingleData(
                    token0.address,
                    one,
                    weth9.address,
                    fee,
                    plugin.address,
                    deadline,
                );

                expect(pluginData.data.length).eq(
                    120,
                    'wrong UNISWAPV3_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH',
                );

                await plugin.execute(pluginData);

                expect(uniswapRouter.exactInputSingle).to.have.been.called;

                // Assertions for all parameters
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].tokenIn,
                ).to.eq(token0.address);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].tokenOut,
                ).to.eq(weth9.address);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].fee,
                ).to.eq(fee);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].recipient,
                ).to.eq(vault);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].deadline,
                ).to.eq(deadline);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].amountIn,
                ).to.eq(one);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0]
                        .amountOutMinimum,
                ).to.eq(0);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0]
                        .sqrtPriceLimitX96,
                ).to.eq(0);
            });

            it('should withdraw ERC20 in exchange for ETH', async function () {
                const pluginData = generateExactInputSingleData(
                    weth9.address,
                    one,
                    token0.address,
                    fee,
                    plugin.address,
                    deadline,
                );

                expect(pluginData.data.length).eq(
                    120,
                    'wrong UNISWAPV3_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH',
                );

                await plugin.execute(pluginData);

                expect(uniswapRouter.exactInputSingle).to.have.been.called;
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].tokenIn,
                ).to.eq(weth9.address);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].tokenOut,
                ).to.eq(token0.address);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].fee,
                ).to.eq(fee);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].recipient,
                ).to.eq(vault);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].deadline,
                ).to.eq(deadline);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0].amountIn,
                ).to.eq(one);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0]
                        .amountOutMinimum,
                ).to.eq(0);
                expect(
                    uniswapRouter.exactInputSingle.getCall(0).args[0]
                        .sqrtPriceLimitX96,
                ).to.eq(0);
            });
        });
    });
});
