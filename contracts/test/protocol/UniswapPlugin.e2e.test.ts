// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {BigNumber} from 'ethers';

import {encodePriceSqrt} from '../../lib/encodePriceSqrt';
import {TokenType} from '../../lib/token';
import {SaltedLockDataStruct} from '../types/contracts/Vault';

import {
    generateExecPluginTestInputs,
    generateExtraInputsHash,
    sampleProof,
} from './data/samples/pantherPool.data';
import {
    generatePrivateMessage,
    TransactionTypes,
} from './data/samples/transactionNote.data';
import {
    composeERC20SenderStealthAddress,
    PluginFixture,
    setupInputFields,
} from './shared';

type Params = {
    deadline: BigNumber;
    sqrtPriceLimitX96: BigNumber;
    fee: number;
};

describe('UniswapPlugin', function () {
    let fixture: PluginFixture;
    let stealthAddress: string;
    let currentLockData: SaltedLockDataStruct;
    // let currentPluginData: PluginDataStruct;
    let cachedForestRootIndex: BigNumber;
    let tokenType: TokenType;
    let inputsArray: any;
    let paymasterCompensation: BigNumber;
    let privateMessage;
    let inputs: BigNumberish[];
    const salt =
        '0x00fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fe';
    const amount = ethers.utils.parseEther('1.0000006789');

    before(async function () {
        fixture = new PluginFixture();
        await fixture.initFixture();
        tokenType = TokenType.Erc20;
        paymasterCompensation = BigNumber.from(0);
        privateMessage = generatePrivateMessage(TransactionTypes.main);

        cachedForestRootIndex = '0';

        currentLockData = {
            tokenType: tokenType,
            token: fixture.zkpToken.address,
            tokenId: 0,
            saltHash: salt,
            extAccount: fixture.ethersSigner.address,
            extAmount: amount,
        };

        inputs = await setupInputFields(
            currentLockData,
            BigNumber.from(0),
            cachedForestRootIndex,
            privateMessage,
            fixture.vault.address,
        );

        inputsArray = Object.values(inputs);

        const hexForestRoot = ethers.utils.hexlify(
            BigNumber.from(inputs.forestMerkleRoot),
        );

        const tx =
            await fixture.pantherPool.internalCacheNewRoot(hexForestRoot);

        await tx.wait();

        const deployerAddress = await fixture.ethersSigner.getAddress();

        expect(await fixture.zkpToken.balanceOf(deployerAddress)).gt(amount);

        stealthAddress = composeERC20SenderStealthAddress(
            currentLockData,
            fixture.vault.address,
        );

        await fixture.zkpToken
            .connect(fixture.ethersSigner)
            .approve(stealthAddress, amount);

        const allowance = await fixture.zkpToken.allowance(
            fixture.ethersSigner.address,
            stealthAddress,
        );

        await expect(allowance).gte(amount);

        expect(
            await fixture.pantherPool.main(
                inputsArray,
                sampleProof,
                cachedForestRootIndex,
                tokenType,
                paymasterCompensation,
                privateMessage,
            ),
        ).to.emit(fixture.vault, 'Locked');

        expect(await fixture.zkpToken.balanceOf(fixture.vault.address)).eq(
            amount,
        );
    });

    //TODO geta it back working accounting code changes
    it.skip('should swapZAsset', async () => {
        cachedForestRootIndex = '1';

        const execPluginInputs = await generateExecPluginTestInputs();

        const hexForestRoot = ethers.utils.hexlify(
            BigNumber.from(execPluginInputs.forestMerkleRoot),
        );

        execPluginInputs.extraInputsHash = generateExtraInputsHash(
            ['uint32', 'uint96', 'bytes'],
            [cachedForestRootIndex, paymasterCompensation, privateMessage],
        );

        const execPluginInputsArray = Object.values(execPluginInputs);

        const tx =
            await fixture.pantherPool.internalCacheNewRoot(hexForestRoot);

        await tx.wait();

        const lockDataIn = {
            tokenType: tokenType,
            token: fixture.zkpToken.address,
            tokenId: 0,
            saltHash: salt,
            extAccount: fixture.uniswapV3Plugin.address,
            extAmount: amount,
        };

        const lockDataOut = {
            tokenType: tokenType,
            token: fixture.weth.address,
            tokenId: 0,
            saltHash: salt,
            extAccount: fixture.vault.address,
            extAmount: amount,
        };

        const sqrtQ96Price = encodePriceSqrt(
            BigNumber.from('1'),
            BigNumber.from('33'),
        );

        const params: Params = {
            deadline: ethers.BigNumber.from('1635799050'), // example timestamp
            sqrtPriceLimitX96: sqrtQ96Price, // example limit
            fee: 500, // example fee
        };

        const encodedParams = ethers.utils.defaultAbiCoder.encode(
            ['tuple(uint256 deadline, uint160 sqrtPriceLimitX96, uint24 fee)'],
            [[params.deadline, params.sqrtPriceLimitX96, params.fee]],
        );

        currentPluginData = {
            destination: fixture.mockUniSwapV3Router.address,
            lDataIn: lockDataIn,
            lDataOut: lockDataOut,
            userData: encodedParams,
        };

        console.log(currentPluginData);

        await expect(
            await fixture.pantherPool.swapZAsset(
                execPluginInputsArray,
                sampleProof,
                cachedForestRootIndex,
                paymasterCompensation,
                fixture.uniswapV3Plugin.address,
                privateMessage,
            ),
        ).to.emit(fixture.pantherPool, 'PluginExecuted');
    });
});
