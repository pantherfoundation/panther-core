// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock, FakeContract} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {getPoseidonT4Contract} from '../../../lib/poseidonBuilder';
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
import {
    getBlockTimestamp,
    revertSnapshot,
    takeSnapshot,
} from '../helpers/hardhat';
import {getMainInputs} from '../helpers/pantherPoolV1Inputs';

describe('ZTransactions', function () {
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

        const PoseidonT4 = await getPoseidonT4Contract();
        const poseidonT4 = await PoseidonT4.deploy();
        await poseidonT4.deployed();

        const ZTransaction = await ethers.getContractFactory(
            'MockZTransaction',
            {
                libraries: {
                    PoseidonT4: poseidonT4.address,
                },
            },
        );

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
            expect(await zTransaction.getPantherTree()).to.equal(
                pantherTrees.address,
            );
        });
    });

    describe('#main', function () {
        it('should execute Internal main transaction and increase feeMasterDebt', async function () {
            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('0'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.constants.AddressZero,
                tokenType: 255,
                kytWithdrawSignedMessageSender: vault.address,
            });

            const chargedZkp = inputs[33];

            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            )
                .to.emit(zTransaction, 'FeesAccounted')
                .withArgs([0, 0])
                .and.to.emit(zTransaction, 'TransactionNote');

            expect(
                await zTransaction.internalfeeMasterDebt(zkpToken.address),
            ).to.be.equal(chargedZkp);

            // Check if the nullifier is spent after the swap
            expect(await zTransaction.internalIsSpent(inputs[7])).to.be.gt(0); //zAssetUtxoInNullifier1
            expect(await zTransaction.internalIsSpent(inputs[8])).to.be.gt(0); //zAssetUtxoInNullifier2
            expect(await zTransaction.internalIsSpent(inputs[9])).to.be.gt(0); //zAccountUtxoInNullifier
        });

        it('should revert Internal main transaction if token address is non zero ', async function () {
            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('0'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.Wallet.createRandom().address,
                tokenType: 255,
                kytWithdrawSignedMessageSender: vault.address,
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E31');
        });

        it('should withdraw token from vault and increase feeMasterDebt', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                tokenType: 0,
                kytWithdrawSignedMessageSender: vault.address,
            });
            const chargedZkp = inputs[33];
            const KytWithdrawMessageHash = ethers.utils.hexZeroPad(
                BigNumber.from(inputs[18]),
                32,
            );

            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            )
                .to.emit(zTransaction, 'FeesAccounted')
                .and.to.emit(zTransaction, 'SeenKytMessageHash')
                .withArgs(KytWithdrawMessageHash)
                .and.to.emit(zTransaction, 'TransactionNote');

            expect(
                await zTransaction.internalfeeMasterDebt(zkpToken.address),
            ).to.be.equal(chargedZkp);
            // Check if the nullifier is spent after the swap
            expect(await zTransaction.internalIsSpent(inputs[7])).to.be.gt(0); //zAssetUtxoInNullifier1
            expect(await zTransaction.internalIsSpent(inputs[8])).to.be.gt(0); //zAssetUtxoInNullifier2
            expect(await zTransaction.internalIsSpent(inputs[9])).to.be.gt(0); //zAccountUtxoInNullifier

            const expectedLockData = {
                tokenType: 0,
                token: zkpToken.address,
                tokenId: BigNumber.from('0'),
                extAccount: inputs[17],
                extAmount: inputs[2],
            };

            expect(vault.unlockAsset).to.have.been.calledOnceWith(
                expectedLockData,
            );
        });

        it('should execute deposit tokens in vault and increase feeMasterDebt', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                tokenType: 0,
                depositPrpAmount: BigNumber.from('10'),
                withdrawPrpAmount: BigNumber.from('0'),
                kytDepositSignedMessageSender: owner.address,
                kytDepositSignedMessageReceiver: vault.address,
            });
            const chargedZkp = inputs[33];
            const KytDepositMessageHash = ethers.utils.hexZeroPad(
                BigNumber.from(inputs[15]),
                32,
            );

            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            )
                .to.emit(zTransaction, 'FeesAccounted')
                .and.to.emit(zTransaction, 'SeenKytMessageHash')
                .withArgs(KytDepositMessageHash)
                .and.to.emit(zTransaction, 'TransactionNote');

            expect(
                await zTransaction.internalfeeMasterDebt(zkpToken.address),
            ).to.be.equal(chargedZkp);
            // Check if the nullifier is spent after the swap
            expect(await zTransaction.internalIsSpent(inputs[7])).to.be.gt(0); //zAssetUtxoInNullifier1
            expect(await zTransaction.internalIsSpent(inputs[8])).to.be.gt(0); //zAssetUtxoInNullifier2
            expect(await zTransaction.internalIsSpent(inputs[9])).to.be.gt(0); //zAccountUtxoInNullifier

            const expectedLockData = {
                tokenType: 0,
                token: zkpToken.address,
                tokenId: BigNumber.from('0'),
                salt: inputs[37],
                extAccount: owner.address,
                extAmount: inputs[1],
            };

            expect(vault.lockAssetWithSalt).to.have.been.calledOnceWith(
                expectedLockData,
            );
        });

        it('should revert if kytDepositSignedMessageReceiver is invalid', async function () {
            const inputs = await getMainInputs({
                depositPrpAmount: BigNumber.from('10'),
                withdrawPrpAmount: BigNumber.from('0'),
                token: ethers.Wallet.createRandom().address,
                tokenType: 0,
                kytDepositSignedMessageReceiver:
                    ethers.Wallet.createRandom().address,
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
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
                tokenType: 0,
                kytDepositSignedMessageReceiver: vault.address,
                kytDepositSignedMessageHash: '0',
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E22');
        });

        it('should revert if kytWithdrawSignedMessageSender is invalid ', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                tokenType: 0,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: owner.address,
            });

            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E23');
        });

        it('should revert if kytWithdrawSignedMessageHash is invalid', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                tokenType: 0,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: vault.address,
                kytWithdrawSignedMessageHash: '0',
            });

            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E25');
        });

        it('should revert if kytWithdrawSignedMessageHash is duplicate ', async function () {
            const inputs = await getMainInputs({
                token: zkpToken.address,
                tokenType: 0,
                withdrawPrpAmount: BigNumber.from('100'),
                kytWithdrawSignedMessageSender: vault.address,
            });

            await zTransaction.main(
                inputs,
                proof,
                transactionOptions,
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
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PP:E37');
        });

        it('should revert if extraInputhash is invalid', async function () {
            const inputs = await getMainInputs({
                extraInputsHash: BigNumber.from('0'),
                token: zkpToken.address,
                tokenType: 0,
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PIG:E4');
        });

        it('should revert if spendTime is invalid', async function () {
            const inputs = await getMainInputs({
                spendTime: (await getBlockTimestamp()) + 10,
                kytWithdrawSignedMessageSender: vault.address,
                token: zkpToken.address,
                tokenType: 0,
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PIG:E3');
        });

        it('should revert if the nullifier is already spent', async function () {
            const inputs = await getMainInputs({
                zAccountUtxoInNullifier: BigNumber.from(1),
                kytWithdrawSignedMessageSender: vault.address,
                token: zkpToken.address,
                tokenType: 0,
            });
            await expect(
                zTransaction.main(
                    inputs,
                    proof,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('SN:E2');
        });
    });
});
