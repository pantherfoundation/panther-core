// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {smock, FakeContract} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {TokenType} from '../../../lib/token';
import {
    MockZTransaction,
    VaultV1,
    IUtxoInserter,
    FeeMaster,
    TokenMock,
} from '../../../types/contracts';
import {SnarkProofStruct} from '../../../types/contracts/IPantherPoolV1';
import {
    generatePrivateMessage,
    TransactionTypes,
} from '../data/samples/transactionNote.data';
import {revertSnapshot, takeSnapshot} from '../helpers/hardhat';
import {getMainInputs} from '../helpers/pantherPoolV1Inputs';

describe.only('ZTransactions', function () {
    let zTransaction: MockZTransaction;

    let zkpToken: TokenMock;
    let feeMaster: FakeContract<FeeMaster>;
    let pantherTrees: FakeContract<IUtxoInserter>;
    let vault: FakeContract<VaultV1>;

    let owner: SignerWithAddress;
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
    const privateMessage = generatePrivateMessage(TransactionTypes.main);

    before(async () => {
        [owner] = await ethers.getSigners();

        const ZkpToken = await ethers.getContractFactory('TokenMock');
        zkpToken = (await ZkpToken.deploy()) as TokenMock;

        feeMaster = await smock.fake('FeeMaster');
        pantherTrees = await smock.fake('IUtxoInserter');
        vault = await smock.fake('VaultV1');
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();

        const ZTransaction =
            await ethers.getContractFactory('MockZTransaction');

        zTransaction = (await ZTransaction.connect(owner).deploy(
            pantherTrees.address,
            vault.address,
            feeMaster.address,
            zkpToken.address,
        )) as MockZTransaction;
    });

    afterEach(async () => {
        await revertSnapshot(snapshot);
    });

    describe('#deployment', () => {
        it('should set the correct panther tree address', async () => {
            expect(await zTransaction.PANTHER_TREES()).to.equal(
                pantherTrees.address,
            );
        });
    });

    describe('#main', function () {
        it('should execute Internal main transaction ', async function () {
            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('0'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.constants.AddressZero,
                kytWithdrawSignedMessageSender: vault.address,
            });
            await zTransaction.main(
                inputs,
                proof,
                transactionOptions,
                TokenType.Erc20,
                paymasterCompensation,
                privateMessage,
            );
        });

        it('should revert Internal main transaction if token address is non zero ', async function () {
            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('0'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.Wallet.createRandom().address,
                kytWithdrawSignedMessageSender: vault.address,
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E31');
        });

        it('should withdraw native token from vault', async function () {
            const extraInput = ethers.utils.solidityPack(
                ['uint32', 'uint8', 'uint96', 'bytes'],
                [
                    transactionOptions,
                    TokenType.Native,
                    paymasterCompensation,
                    privateMessage,
                ],
            );
            const calculatedExtraInputHash = BigNumber.from(
                ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
            ).mod(SNARK_FIELD_SIZE);

            const inputs = await getMainInputs({
                extraInputsHash: calculatedExtraInputHash,
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.constants.AddressZero,
                kytWithdrawSignedMessageSender: vault.address,
            });

            const withdrawAmount = inputs[2];

            const balanceOfVault = await ethers.provider.getBalance(
                vault.address,
            );

            await zTransaction.main(
                inputs,
                proof,
                transactionOptions,
                TokenType.Native,
                paymasterCompensation,
                privateMessage,
            );

            expect(await ethers.provider.getBalance(vault.address)).to.be.equal(
                balanceOfVault.sub(withdrawAmount),
            );
        });

        it('should withdraw token from vault', async function () {
            await zkpToken.transfer(vault.address, BigNumber.from('100'));
            await zkpToken.increaseAllowance(
                vault.address,
                BigNumber.from('100'),
            );

            const inputs = await getMainInputs({
                token: zkpToken.address,
                kytWithdrawSignedMessageSender: vault.address,
            });

            await zTransaction.main(
                inputs,
                proof,
                transactionOptions,
                TokenType.Erc20,
                paymasterCompensation,
                privateMessage,
            );
        });

        it('should execute deposit main transaction', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                depositPrpAmount: BigNumber.from('10'),
                withdrawPrpAmount: BigNumber.from('0'),
                kytDepositSignedMessageSender: owner.address,
                kytDepositSignedMessageReceiver: vault.address,
            });

            await zTransaction
                .connect(owner)
                .main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                );
        });

        it('should revert if kytDepositSignedMessageReceiver is invalid', async function () {
            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('10'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.Wallet.createRandom().address,
                kytDepositSignedMessageReceiver:
                    ethers.Wallet.createRandom().address,
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E21');
        });

        it('should revert if kytDepositSignedMessageHash is invalid', async function () {
            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('10'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: zkpToken.address,
                kytDepositSignedMessageReceiver: vault.address,
                kytDepositSignedMessageHash: '0',
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E22');
        });

        it('should revert if kytWithdrawSignedMessageSender is invalid ', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: owner.address,
            });

            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E23');
        });

        it('should revert if kytWithdrawSignedMessageHash is invalid', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: vault.address,
                kytWithdrawSignedMessageHash: '0',
            });

            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E25');
        });

        it('should revert if kytWithdrawSignedMessageHash is duplicate ', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: vault.address,
                kytWithdrawSignedMessageHash: ethers.utils.id(
                    'kytWithdrawSignedMessageHash',
                ),
            });

            await zTransaction.main(
                inputs,
                proof,
                transactionOptions,
                TokenType.Erc20,
                paymasterCompensation,
                privateMessage,
            );
            inputs[7] = ethers.utils.id('randomNullifier1');
            inputs[8] = ethers.utils.id('randomNullifier2');
            inputs[9] = ethers.utils.id('nullifier');

            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    TokenType.Erc20,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E37');
        });
    });
});
