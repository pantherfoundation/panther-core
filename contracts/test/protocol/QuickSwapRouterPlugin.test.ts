// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {smock} from '@defi-wonderland/smock';
import chai, {expect} from 'chai';
import {Contract} from 'ethers';
import {ethers} from 'hardhat';

import {generateExactInputData} from '../../lib/pluginData';
import {TokenType} from '../../lib/token';
import {MockERC20} from '../../types/contracts';

import {ADDRESS_ONE} from './helpers/constants';

chai.use(smock.matchers);

const one = ethers.utils.parseEther('1');

describe('QuickswapRouterPlugin', function () {
    let plugin: Contract;
    let owner: any;
    let quickswapRouter: any;
    let quickswapFactory: any;
    let weth: any;
    let tokenA: MockERC20;
    let tokenB: MockERC20;
    let vault: string;
    let deadline: number;
    let pluginData;
    const amountIn = ethers.utils.parseEther('1');
    const amountOutMin = ethers.utils.parseEther('0');

    async function setupFixture() {
        deadline = 1;

        [owner] = await ethers.getSigners();

        const MockERC20 = await ethers.getContractFactory('MockERC20');

        tokenA = await MockERC20.deploy(0, owner.address);
        await tokenA.deployed();

        tokenB = await MockERC20.deploy(0, owner.address);
        await tokenB.deployed();

        vault = owner.address;

        quickswapRouter = await smock.fake('IUniswapV2Router');
        quickswapFactory = await smock.fake('IUniswapV2Factory');
        weth = await smock.fake('IWETH');
        weth.approve.returns(true);

        quickswapRouter.swapExactTokensForTokens.returns([1, 2, 3]);
        quickswapRouter.swapExactTokensForETH.returns([1, 2, 3]);
        quickswapRouter.swapExactETHForTokens.returns([1, 2, 3]);
        quickswapRouter.getAmountsOut.returns([1, 2, 3]);

        quickswapFactory.getPair.returns(ADDRESS_ONE);

        const QuickswapRouterPluginFactory = await ethers.getContractFactory(
            'QuickswapRouterPlugin',
        );

        plugin = await QuickswapRouterPluginFactory.deploy(
            quickswapRouter.address,
            quickswapFactory.address,
            vault,
            weth.address,
        );

        await plugin.deployed();
    }

    context('Configuration', () => {
        before(async function () {
            await setupFixture();
        });

        it('should deploy the contract with the correct addresses', async function () {
            expect(await plugin.QUICKSWAP_ROUTER()).to.equal(
                quickswapRouter.address,
            );
            expect(await plugin.QUICKSWAP_FACTORY()).to.equal(
                quickswapFactory.address,
            );
            expect(await plugin.VAULT()).to.equal(vault);
        });
    });

    context('Swaps', () => {
        before(async function () {
            await setupFixture();
        });

        it('should swap ERC20 tokens', async function () {
            pluginData = generateExactInputData(
                tokenA.address,
                TokenType.Erc20,
                tokenB.address,
                TokenType.Erc20,
                amountIn.toBigInt(),
                plugin.address,
                amountOutMin.toBigInt(),
                deadline,
            );

            await plugin.execute(pluginData);

            expect(quickswapRouter.swapExactTokensForTokens).to.have.been
                .called;

            // Assertions for all parameters
            expect(
                quickswapRouter.swapExactTokensForTokens.getCall(0).args[0],
            ).to.eq(amountIn);
            expect(
                quickswapRouter.swapExactTokensForTokens.getCall(0).args[1],
            ).to.eq(amountOutMin);
            expect(
                quickswapRouter.swapExactTokensForTokens.getCall(0).args[2][0],
            ).to.eq(tokenA.address);
            expect(
                quickswapRouter.swapExactTokensForTokens.getCall(0).args[2][1],
            ).to.eq(tokenB.address);
            expect(
                quickswapRouter.swapExactTokensForTokens.getCall(0).args[3],
            ).to.eq(vault);
            expect(
                quickswapRouter.swapExactTokensForTokens.getCall(0).args[4],
            ).to.eq(deadline);
        });

        it('should swap ETH for ERC20', async function () {
            const pluginData = generateExactInputData(
                tokenA.address,
                TokenType.Erc20,
                weth.address,
                TokenType.Native,
                one,
                plugin.address,
                BigInt(0),
                deadline,
            );

            await plugin.execute(pluginData);

            expect(quickswapRouter.swapExactTokensForETH).to.have.been.called;

            // Assertions for all parameters
            expect(
                quickswapRouter.swapExactTokensForETH.getCall(0).args[0],
            ).to.eq(one);
            expect(
                quickswapRouter.swapExactTokensForETH.getCall(0).args[1],
            ).to.eq(0);
            expect(
                quickswapRouter.swapExactTokensForETH.getCall(0).args[2][0],
            ).to.eq(tokenA.address);
            expect(
                quickswapRouter.swapExactTokensForETH.getCall(0).args[2][1],
            ).to.eq(weth.address);
            expect(
                quickswapRouter.swapExactTokensForETH.getCall(0).args[3],
            ).to.eq(vault);
            expect(
                quickswapRouter.swapExactTokensForETH.getCall(0).args[4],
            ).to.eq(deadline);
        });

        it('should swap ERC20 for ETH', async function () {
            await owner.sendTransaction({to: plugin.address, value: one});

            const pluginData = generateExactInputData(
                weth.address,
                TokenType.Native,
                tokenA.address,
                TokenType.Erc20,
                one,
                plugin.address,
                BigInt(0),
                deadline,
            );

            await plugin.execute(pluginData);

            expect(quickswapRouter.swapExactETHForTokens).to.have.been.called;

            expect(
                quickswapRouter.swapExactETHForTokens.getCall(0).args
                    .amountOutMin,
            ).to.eq(0);

            expect(
                quickswapRouter.swapExactETHForTokens.getCall(0).args.path[0],
            ).to.eq(weth.address);

            expect(
                quickswapRouter.swapExactETHForTokens.getCall(0).args.to,
            ).to.eq(vault);
            expect(
                quickswapRouter.swapExactETHForTokens.getCall(0).args.deadline,
            ).to.eq(deadline);
        });
    });

    context('Get out amount', () => {
        before(async function () {
            await setupFixture();
        });

        it('should execute router getAmountOut', async function () {
            await plugin.getAmountOut(tokenA.address, tokenB.address, amountIn);

            expect(quickswapRouter.getAmountsOut).to.have.been.called;
        });
    });
});
