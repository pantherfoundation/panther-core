// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumber} from 'ethers';
import {task} from 'hardhat/config';

const TASK_UNISWAP_V3_ROUTER_PLUGIN_SWAP = 'uniswap-v3-router-plugin:swap';

// Helper function to encode token type and address
const encodeTokenTypeAndAddress = (
    type: number,
    address: string,
): BigNumber => {
    return BigNumber.from(type).shl(160).add(address);
};

task(
    TASK_UNISWAP_V3_ROUTER_PLUGIN_SWAP,
    'Deploy UniswapV3RouterPlugin and execute USDT to USDC swap',
).setAction(async (_, {ethers, network}) => {
    // Addresses
    const WHALE_ADDRESS = '0xF977814e90dA44bFA03b6295A0616a897441aceC';
    const USDT_ADDRESS = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
    const USDC_ADDRESS = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
    const UNISWAP_ROUTER = '0xE592427A0AEce92De3Edee1F18E0157C05861564';
    const UNISWAP_QUOTER_V2 = '0x61fFE014bA17989E743c5F6cB21bF9697530B21e';
    const VAULT_V1 = '0x51a882B1f161c72E351B64871AB3C9779719030b';

    console.log('Impersonating whale account...');
    await network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [WHALE_ADDRESS],
    });
    const whale = await ethers.getSigner(WHALE_ADDRESS);

    // 1. Deploy UniswapV3RouterPlugin
    console.log('Deploying UniswapV3RouterPlugin...');
    const UniswapV3RouterPlugin = await ethers.getContractFactory(
        'UniswapV3RouterPlugin',
    );
    const plugin = await UniswapV3RouterPlugin.deploy(
        UNISWAP_ROUTER,
        UNISWAP_QUOTER_V2,
        VAULT_V1,
    );
    await plugin.deployed();
    console.log(`UniswapV3RouterPlugin deployed at: ${plugin.address}`);

    // Get USDT contract
    const usdtContract = await ethers.getContractAt('IERC20', USDT_ADDRESS);

    // Amount to swap (100 USDT with 6 decimals)
    const amountIn = ethers.utils.parseUnits('100', 6);

    // Check USDT balance of whale
    const whaleUsdtBalance = await usdtContract.balanceOf(WHALE_ADDRESS);
    console.log(
        `Whale USDT balance: ${ethers.utils.formatUnits(whaleUsdtBalance, 6)}`,
    );

    // Check if whale has enough USDT
    if (whaleUsdtBalance.lt(amountIn)) {
        console.error("Whale doesn't have enough USDT!");
        return;
    }

    // 2. Get quote using static call to quoteExactInput
    console.log('Getting quote for USDT to USDC swap...');
    const quoteResult = await plugin.callStatic.quoteExactInput(
        USDT_ADDRESS,
        USDC_ADDRESS,
        amountIn,
    );

    const path = quoteResult.path;
    const amountOut = quoteResult.amountOut;

    console.log(
        `Expected output amount: ${ethers.utils.formatUnits(
            amountOut,
            6,
        )} USDC`,
    );

    // 3. Transfer USDT from whale to plugin
    console.log('Transferring USDT from whale to plugin...');
    await usdtContract.connect(whale).transfer(plugin.address, amountIn);

    // 4. Prepare plugin data for execute
    const deadline = BigNumber.from(Math.floor(Date.now() / 1000) + 600); // 10 minutes from now
    const amountOutMinimum = amountOut.mul(95).div(100); // 95% of expected amount out (slippage protection)

    // Encode plugin data
    // Format: plugin address + deadline + amountOutMinimum + path
    const pluginAddress = plugin.address;

    // Encode data for execute function
    const data = ethers.utils.solidityPack(
        ['address', 'uint32', 'uint96', 'bytes'],
        [pluginAddress, deadline, amountOutMinimum, path],
    );

    // Create PluginData struct
    const pluginData = {
        tokenInTypeAndAddress: encodeTokenTypeAndAddress(0, USDT_ADDRESS),
        tokenOutTypeAndAddress: encodeTokenTypeAndAddress(0, USDC_ADDRESS),
        amountIn: amountIn,
        data: data,
    };

    // 5. Execute the swap
    console.log('Executing swap...');
    const tx = await plugin.connect(whale).execute(pluginData);
    const receipt = await tx.wait();

    console.log(
        `Swap executed successfully! Transaction hash: ${receipt.transactionHash}`,
    );

    // Check USDC balance of the vault after swap
    const usdcContract = await ethers.getContractAt('IERC20', USDC_ADDRESS);
    const vaultUsdcBalance = await usdcContract.balanceOf(VAULT_V1);
    console.log(
        `Vault USDC balance after swap: ${ethers.utils.formatUnits(
            vaultUsdcBalance,
            6,
        )}`,
    );
});
