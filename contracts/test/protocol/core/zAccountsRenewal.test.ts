// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {smock, FakeContract} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {
    MockZAccountsRenewal,
    IUtxoInserter,
    FeeMaster,
    IERC20,
} from '../../../types/contracts';
import {SnarkProofStruct} from '../../../types/contracts/ZAccountsRegistration';
import {
    generatePrivateMessage,
    TransactionTypes,
} from '../data/samples/transactionNote.data';
import {
    getBlockTimestamp,
    revertSnapshot,
    takeSnapshot,
} from '../helpers/hardhat';
import {getzAccountRenewalInputs} from '../helpers/pantherPoolV1Inputs';

describe('ZAccountsRenewal', function () {
    let zAccountsRenewal: MockZAccountsRenewal;

    let zkpToken: FakeContract<IERC20>;
    let feeMaster: FakeContract<FeeMaster>;
    let pantherTrees: FakeContract<IUtxoInserter>;

    let owner: SignerWithAddress;
    let snapshot: number;

    const placeholder = BigNumber.from(0);
    const proofs = {
        a: {x: placeholder, y: placeholder},
        b: {
            x: [placeholder, placeholder],
            y: [placeholder, placeholder],
        },
        c: {x: placeholder, y: placeholder},
    } as SnarkProofStruct;
    const privateMessages = generatePrivateMessage(
        TransactionTypes.zAccountRenewal,
    );
    const transactionOptions = 0x102;
    const paymasterCompensation = ethers.BigNumber.from('10');

    before(async () => {
        [owner] = await ethers.getSigners();

        zkpToken = await smock.fake('IERC20');
        feeMaster = await smock.fake('FeeMaster');
        pantherTrees = await smock.fake('IUtxoInserter');
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();

        const ZAccountsRenewal = await ethers.getContractFactory(
            'MockZAccountsRenewal',
        );

        zAccountsRenewal = (await ZAccountsRenewal.connect(owner).deploy(
            owner.address,
            pantherTrees.address,
            feeMaster.address,
            zkpToken.address,
        )) as MockZAccountsRenewal;
    });

    afterEach(async () => {
        await revertSnapshot(snapshot);
    });

    describe('#renewZAccount', () => {
        describe('Success', () => {
            it('should renew zAccount and update FeeMaster Debt', async () => {
                const inputs = await getzAccountRenewalInputs({});
                const chargedZkp = inputs[2];

                await expect(
                    zAccountsRenewal.renewZAccount(
                        inputs,
                        proofs,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
                )
                    .to.emit(zAccountsRenewal, 'FeesAccounted')
                    .and.to.emit(zAccountsRenewal, 'TransactionNote');

                expect(
                    await zAccountsRenewal.internalIsSpent(inputs[3]),
                ).to.be.gt(0); //nullifier

                expect(
                    await zAccountsRenewal.internalFeeMasterDebt(
                        zkpToken.address,
                    ),
                ).to.be.equal(chargedZkp); //chargedAmountZkp
            });
        });

        describe('Failure', () => {
            it('should revert if the extraInputsHash is larger than FIELD_SIZE', async () => {
                const invalidInputsHash = ethers.BigNumber.from('12345');

                const inputs = await getzAccountRenewalInputs({
                    extraInputsHash: invalidInputsHash,
                });

                await expect(
                    zAccountsRenewal.renewZAccount(
                        inputs,
                        proofs,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
                ).to.be.revertedWith('PIG:E4');
            });

            it('should revert if a nullifier is already spent', async () => {
                const inputs = await getzAccountRenewalInputs({});

                await zAccountsRenewal.renewZAccount(
                    inputs,
                    proofs,
                    transactionOptions,
                    paymasterCompensation,
                    privateMessages,
                );

                await expect(
                    zAccountsRenewal.renewZAccount(
                        inputs,
                        proofs,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
                ).to.be.revertedWith('SN:E2');
            });

            it('should revert if salt hash is zero', async function () {
                const inputs = await getzAccountRenewalInputs({
                    saltHash: '0',
                });

                await expect(
                    zAccountsRenewal.renewZAccount(
                        inputs,
                        proofs,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
                ).to.revertedWith('ERR_ZERO_SALT_HASH');
            });

            it('should revert if magicalConstraint is zero', async function () {
                const inputs = await getzAccountRenewalInputs({
                    magicalConstraint: '0',
                });

                await expect(
                    zAccountsRenewal.renewZAccount(
                        inputs,
                        proofs,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
                ).to.revertedWith('ERR_ZERO_MAGIC_CONSTR');
            });

            it('should revert if commitment is zero', async function () {
                const inputs = await getzAccountRenewalInputs({
                    commitment: '0',
                });

                await expect(
                    zAccountsRenewal.renewZAccount(
                        inputs,
                        proofs,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
                ).to.revertedWith('ERR_ZERO_ZACCOUNT_COMMIT');
            });

            it('should revert if kycSignedMessageHash is zero', async function () {
                const inputs = await getzAccountRenewalInputs({
                    kycSignedMessageHash: '0',
                });

                await expect(
                    zAccountsRenewal.renewZAccount(
                        inputs,
                        proofs,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
                ).to.revertedWith('ERR_ZERO_KYC_MSG_HASH');
            });

            it('should revert if create Time is invalid', async function () {
                const inputs = await getzAccountRenewalInputs({
                    utxoOutCreateTime: (await getBlockTimestamp()) - 10,
                });

                await expect(
                    zAccountsRenewal.renewZAccount(
                        inputs,
                        proofs,
                        transactionOptions,
                        paymasterCompensation,
                        privateMessages,
                    ),
                ).to.revertedWith('PIG:E1');
            });
        });
    });
});
