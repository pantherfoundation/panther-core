// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {smock, FakeContract} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {getPoseidonT3Contract} from '../../../lib/poseidonBuilder';
import {
    MockZSwap,
    VaultV1,
    IUtxoInserter,
    FeeMaster,
    TokenMock,
    IPlugin,
} from '../../../types/contracts';
import {SnarkProofStruct} from '../../../types/contracts/IPantherPoolV1';
import {
    generatePrivateMessage,
    TransactionTypes,
} from '../data/samples/transactionNote.data';
import {revertSnapshot, takeSnapshot} from '../helpers/hardhat';
import {
    encodeTokenTypeAndAddress,
    getSwapInputs,
} from '../helpers/pantherPoolV1Inputs';

describe('ZSwap', function () {
    let zSwap: MockZSwap;
    let zkpToken: TokenMock;
    let linkToken: TokenMock;
    let feeMaster: FakeContract<FeeMaster>;
    let pantherTrees: FakeContract<IUtxoInserter>;
    let vault: FakeContract<VaultV1>;
    let plugin: FakeContract<IPlugin>;
    let owner: SignerWithAddress, notOwner: SignerWithAddress;
    let snapshot: number;

    const placeholder = BigNumber.from(0);
    const proof = {
        a: {x: placeholder, y: placeholder},
        b: {
            x: [placeholder, placeholder],
            y: [placeholder, placeholder],
        },
        c: {x: placeholder, y: placeholder},
    } as SnarkProofStruct;

    const transactionOptions = 0;
    const paymasterCompensation = ethers.BigNumber.from('10');
    const privateMessage = generatePrivateMessage(TransactionTypes.swapZAsset);

    before(async () => {
        [, owner, notOwner] = await ethers.getSigners();

        const ZkpToken = await ethers.getContractFactory('TokenMock');
        zkpToken = (await ZkpToken.deploy()) as TokenMock;

        const LinkToken = await ethers.getContractFactory('TokenMock');
        linkToken = (await LinkToken.deploy()) as TokenMock;

        feeMaster = await smock.fake('FeeMaster');
        pantherTrees = await smock.fake('IUtxoInserter');
        vault = await smock.fake('VaultV1');
        plugin = await smock.fake('IPlugin');
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();

        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        const ZSwap = await ethers.getContractFactory('MockZSwap', {
            libraries: {
                PoseidonT3: poseidonT3.address,
            },
        });

        zSwap = (await ZSwap.connect(owner).deploy(
            pantherTrees.address,
            vault.address,
            feeMaster.address,
            zkpToken.address,
        )) as MockZSwap;
    });

    afterEach(async () => {
        await revertSnapshot(snapshot);
    });

    describe('#deployment', () => {
        it('should set the correct panther tree and vault address', async () => {
            const result = await zSwap.getPantherTreeAndVaultAddr();

            expect(result.vault).to.equal(vault.address);
            expect(result.pantherTree).to.equal(pantherTrees.address);
        });
    });

    describe('#updatePluginStatus', () => {
        it('should update Plugin Status and emit ZSwapPluginUpdated event', async () => {
            await expect(zSwap.updatePluginStatus(plugin.address, true))
                .to.emit(zSwap, 'ZSwapPluginUpdated')
                .withArgs(plugin.address, true);

            expect(await zSwap.zSwapPlugins(plugin.address)).to.be.true;
        });

        it('should revert if not executed by owner ', async () => {
            await expect(
                zSwap
                    .connect(notOwner)
                    .updatePluginStatus(plugin.address, true),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('#swap', function () {
        async function getSwapDataAndHash() {
            const swapData = ethers.utils.solidityPack(
                ['address'],
                [plugin.address],
            );

            const extraInput = ethers.utils.solidityPack(
                ['uint32', 'uint96', 'bytes', 'bytes'],
                [
                    transactionOptions,
                    paymasterCompensation,
                    swapData,
                    privateMessage,
                ],
            );
            const calculatedExtraInputHash = BigNumber.from(
                ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
            ).mod(SNARK_FIELD_SIZE);

            return {swapData, calculatedExtraInputHash};
        }

        describe('success', () => {
            beforeEach(async () => {
                await zSwap.updatePluginStatus(plugin.address, true);

                //mocked functions
                plugin.execute.returns(100);
                vault.getBalance.returnsAtCall(0, 100);
                vault.getBalance.returnsAtCall(1, 200);
            });

            it('should execute swap and update the FeeMasterDebt', async function () {
                const {swapData, calculatedExtraInputHash} =
                    await getSwapDataAndHash();

                const withdrawAmount = ethers.utils.parseEther('10');

                const inputs = await getSwapInputs({
                    extraInputsHash: calculatedExtraInputHash,
                    existingToken: zkpToken.address,
                    incomingToken: linkToken.address,
                    existingTokenType: 0,
                    incomingTokenType: 0,
                    withdrawPrpAmount: withdrawAmount,
                    incomingZassetScale: BigNumber.from('1000000'),
                    existingZassetScale: BigNumber.from('1000000'),
                    kytWithdrawSignedMessageSender: vault.address,
                    kytDepositSignedMessageReceiver: vault.address,
                });

                await expect(
                    zSwap.swapZAsset(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        swapData,
                        privateMessage,
                    ),
                )
                    .to.emit(zSwap, 'FeesAccounted')
                    .and.to.emit(zSwap, 'TransactionNote');

                expect(vault.unlockAsset).to.have.been.calledOnceWith({
                    tokenType: 0,
                    token: zkpToken.address,
                    tokenId: BigNumber.from('0'),
                    extAccount: plugin.address,
                    extAmount: withdrawAmount,
                });

                expect(plugin.execute).to.have.been.calledOnceWith({
                    tokenIn: zkpToken.address,
                    tokenOut: linkToken.address,
                    amountIn: withdrawAmount,
                    tokenType: 0,
                    data: swapData,
                });
                // Check if the nullifier is spent after the swap
                expect(await zSwap.internalIsSpent(inputs[12])).to.be.gt(0); //zAssetUtxoInNullifier1
                expect(
                    await zSwap.internalFeeMasterDebt(zkpToken.address),
                ).to.be.equal(inputs[41]); //chargedAmountZkp
            });
        });

        describe('failure', () => {
            it('should revert if ExtraInputHash is not valid', async function () {
                const {swapData} = await getSwapDataAndHash();

                const inputs = await getSwapInputs({
                    extraInputsHash: BigNumber.from('1'),
                    existingToken: zkpToken.address,
                    incomingToken: linkToken.address,
                    existingTokenType: 0,
                    incomingTokenType: 0,
                    kytWithdrawSignedMessageSender: vault.address,
                    kytDepositSignedMessageReceiver: vault.address,
                });

                await expect(
                    zSwap.swapZAsset(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        swapData,
                        privateMessage,
                    ),
                ).to.revertedWith('PIG:E4');
            });

            it('should revert if salt hash is zero', async function () {
                const {swapData, calculatedExtraInputHash} =
                    await getSwapDataAndHash();

                const inputs = await getSwapInputs({
                    extraInputsHash: calculatedExtraInputHash,
                    existingToken: zkpToken.address,
                    incomingToken: linkToken.address,
                    existingTokenType: 0,
                    incomingTokenType: 0,
                    kytWithdrawSignedMessageSender: vault.address,
                    kytDepositSignedMessageReceiver: vault.address,
                    saltHash: '0',
                });

                await expect(
                    zSwap.swapZAsset(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        swapData,
                        privateMessage,
                    ),
                ).to.revertedWith('ZS:E2');
            });

            it('should revert when trying to spend a nullifier twice', async function () {
                await zSwap.updatePluginStatus(plugin.address, true);

                const {swapData, calculatedExtraInputHash} =
                    await getSwapDataAndHash();

                const inputs = await getSwapInputs({
                    extraInputsHash: calculatedExtraInputHash,
                    existingToken: zkpToken.address,
                    incomingToken: linkToken.address,
                    existingTokenType: 0,
                    incomingTokenType: 0,
                    withdrawPrpAmount: ethers.utils.parseEther('10'),
                    incomingZassetScale: BigNumber.from('1000000'),
                    existingZassetScale: BigNumber.from('1000000'),
                    kytWithdrawSignedMessageSender: vault.address,
                    kytDepositSignedMessageReceiver: vault.address,
                });

                plugin.execute.returns(100);
                vault.getBalance.returnsAtCall(2, 100);
                vault.getBalance.returnsAtCall(3, 200);

                // First swap should succeed
                await zSwap.swapZAsset(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    swapData,
                    privateMessage,
                );

                // Second swap with the same nullifier should fail
                await expect(
                    zSwap.swapZAsset(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        swapData,
                        privateMessage,
                    ),
                ).to.be.revertedWith('SN:E2');
            });

            it('should revert if plugin id not found', async function () {
                const {swapData, calculatedExtraInputHash} =
                    await getSwapDataAndHash();

                const inputs = await getSwapInputs({
                    extraInputsHash: calculatedExtraInputHash,
                    existingToken: zkpToken.address,
                    incomingToken: linkToken.address,
                    existingTokenType: 0,
                    incomingTokenType: 0,
                    kytWithdrawSignedMessageSender: vault.address,
                    kytDepositSignedMessageReceiver: vault.address,
                });

                await expect(
                    zSwap.swapZAsset(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        swapData,
                        privateMessage,
                    ),
                ).to.revertedWith('ZS:E1');
            });

            it('should revert if the output amount is zero', async function () {
                await zSwap.updatePluginStatus(plugin.address, true);

                const {swapData, calculatedExtraInputHash} =
                    await getSwapDataAndHash();

                const inputs = await getSwapInputs({
                    extraInputsHash: calculatedExtraInputHash,
                    existingToken: zkpToken.address,
                    incomingToken: linkToken.address,
                    existingTokenType: 0,
                    incomingTokenType: 0,
                    kytWithdrawSignedMessageSender: vault.address,
                    kytDepositSignedMessageReceiver: vault.address,
                });

                plugin.execute.returns(0);

                await expect(
                    zSwap.swapZAsset(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        swapData,
                        privateMessage,
                    ),
                ).to.revertedWith('Zero received amount');
            });

            it('should revert if there is mismatch between outputAmount and receivedAmount', async function () {
                await zSwap.updatePluginStatus(plugin.address, true);

                const {swapData, calculatedExtraInputHash} =
                    await getSwapDataAndHash();

                const inputs = await getSwapInputs({
                    extraInputsHash: calculatedExtraInputHash,
                    existingToken: zkpToken.address,
                    incomingToken: linkToken.address,
                    existingTokenType: 0,
                    incomingTokenType: 0,
                    kytWithdrawSignedMessageSender: vault.address,
                    kytDepositSignedMessageReceiver: vault.address,
                });

                plugin.execute.returns(100);
                vault.getBalance.returns(100);

                await expect(
                    zSwap.swapZAsset(
                        inputs,
                        proof,
                        transactionOptions,
                        paymasterCompensation,
                        swapData,
                        privateMessage,
                    ),
                ).to.revertedWith('Unexpected vault balance');
            });
        });
    });

    describe('#_getTokenTypeAndAddress', function () {
        it('should decode token type and address', async function () {
            const nativeTypeAndToken = encodeTokenTypeAndAddress(
                0xff,
                ethers.constants.AddressZero,
            );
            const erc20TypeAndToken = encodeTokenTypeAndAddress(
                0,
                zkpToken.address,
            );

            expect(
                (await zSwap.internalGetTokenTypeAndAddress(erc20TypeAndToken))
                    .tokenType,
            ).to.be.equal(0);
            expect(
                (await zSwap.internalGetTokenTypeAndAddress(erc20TypeAndToken))
                    .tokenAddress,
            ).to.be.equal(zkpToken.address);

            expect(
                (await zSwap.internalGetTokenTypeAndAddress(nativeTypeAndToken))
                    .tokenType,
            ).to.be.equal(255);
            expect(
                (await zSwap.internalGetTokenTypeAndAddress(nativeTypeAndToken))
                    .tokenAddress,
            ).to.be.equal(ethers.constants.AddressZero);
        });
    });
});
