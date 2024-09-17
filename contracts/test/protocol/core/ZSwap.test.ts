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
import {getSwapInputs} from '../helpers/pantherPoolV1Inputs';

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
            expect(await zSwap.PANTHER_TREES()).to.equal(pantherTrees.address);

            expect(await zSwap.VAULT()).to.equal(vault.address);
        });
    });

    describe('#updatePluginStatus', () => {
        it('should update Plugin Status', async () => {
            await expect(zSwap.updatePluginStatus(plugin.address, true))
                .to.emit(zSwap, 'ZSwapPluginUpdated')
                .withArgs(plugin.address, true);
        });

        it('should revert if not executed by owner ', async () => {
            await expect(
                zSwap
                    .connect(notOwner)
                    .updatePluginStatus(plugin.address, true),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('#swap', async function () {
        before(async function () {
            await zkpToken.transfer(
                vault.address,
                ethers.utils.parseEther('100'),
            );
            await zkpToken.increaseAllowance(
                vault.address,
                ethers.utils.parseEther('100'),
            );
            await linkToken.transfer(
                plugin.address,
                ethers.utils.parseEther('100'),
            );
            await linkToken.increaseAllowance(
                plugin.address,
                ethers.utils.parseEther('100'),
            );
        });

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

        it('should update plugin status and swap tokens', async function () {
            await zSwap.updatePluginStatus(plugin.address, true);

            const {swapData, calculatedExtraInputHash} =
                await getSwapDataAndHash();

            const inputs = await getSwapInputs({
                extraInputsHash: calculatedExtraInputHash,
                existingToken: zkpToken.address,
                incomingToken: linkToken.address,
                withdrawPrpAmount: ethers.utils.parseEther('10'),
                incomingZassetScale: BigNumber.from('1000000'),
                existingZassetScale: BigNumber.from('1000000'),
                kytWithdrawSignedMessageSender: vault.address,
                kytDepositSignedMessageReceiver: vault.address,
            });

            //mocked functions
            plugin.execute.returns(100);
            vault.getBalance.returnsAtCall(0, 100);
            vault.getBalance.returnsAtCall(1, 200);

            await zSwap.swapZAsset(
                inputs,
                proof,
                transactionOptions,
                paymasterCompensation,
                swapData,
                privateMessage,
            );
        });

        it('should revert if plugin id not found', async function () {
            const {swapData, calculatedExtraInputHash} =
                await getSwapDataAndHash();

            const inputs = await getSwapInputs({
                extraInputsHash: calculatedExtraInputHash,
                existingToken: zkpToken.address,
                incomingToken: linkToken.address,
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
            ).to.revertedWith('OW:E1');
        });

        it('should revert if the output amount is zero', async function () {
            await zSwap.updatePluginStatus(plugin.address, true);

            const {swapData, calculatedExtraInputHash} =
                await getSwapDataAndHash();

            const inputs = await getSwapInputs({
                extraInputsHash: calculatedExtraInputHash,
                existingToken: zkpToken.address,
                incomingToken: linkToken.address,
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
