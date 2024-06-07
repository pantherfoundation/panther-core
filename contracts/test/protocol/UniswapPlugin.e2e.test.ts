// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {expect} from 'chai';
import {BigNumber} from 'ethers';

import {TokenType} from '../../lib/token';
import {SaltedLockDataStruct} from '../types/contracts/Vault';

import {
    generateExtraInputsHash,
    generatezAssetSwapTestInputs,
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

const oneToken = ethers.constants.WeiPerEther;

describe.skip('UniswapPlugin', function () {
    let fixture: PluginFixture;
    let stealthAddress: string;
    let currentLockData: SaltedLockDataStruct;
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

    it('should revert swapZAsset as plugin not updated yet', async () => {
        cachedForestRootIndex = '1';
        privateMessage = generatePrivateMessage(TransactionTypes.swapZAsset);
        const inputs = await generatezAssetSwapTestInputs(
            fixture.zkpToken.address,
            fixture.weth.address,
            oneToken,
            '0',
        );

        inputs.extraInputsHash = generateExtraInputsHash(
            ['uint32', 'uint96', 'address', 'bytes'],
            [
                cachedForestRootIndex,
                paymasterCompensation,
                fixture.uniswapV3Plugin.address,
                privateMessage,
            ],
        );

        const hexForestRoot = ethers.utils.hexlify(
            BigNumber.from(inputs.forestMerkleRoot),
        );

        const execPluginInputsArray = Object.values(inputs);

        const tx =
            await fixture.pantherPool.internalCacheNewRoot(hexForestRoot);

        await tx.wait();

        await expect(
            fixture.pantherPool.swapZAsset(
                execPluginInputsArray,
                sampleProof,
                cachedForestRootIndex,
                paymasterCompensation,
                fixture.uniswapV3Plugin.address,
                privateMessage,
            ),
        ).to.revertedWith('Zero output');
        // .to.emit(fixture.pantherPool, 'PluginExecuted');
    });
});
