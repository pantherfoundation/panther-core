// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock, FakeContract} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {getPoseidonT3Contract} from '../../../lib/poseidonBuilder';
import {
    MockPrpConversion,
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
import {getPrpClaimandConversionInputs} from '../helpers/pantherPoolV1Inputs';

describe('PrpConversion', function () {
    let prpConversion: MockPrpConversion;

    let zkpToken: TokenMock;
    let feeMaster: FakeContract<FeeMaster>;
    let pantherTrees: FakeContract<IUtxoInserter>;
    let vault: FakeContract<VaultV1>;

    let owner: SignerWithAddress, notOwner: SignerWithAddress;
    let snapshot: number;

    const privateMessage = generatePrivateMessage(
        TransactionTypes.prpConversion,
    );
    const zkpAmount = ethers.utils.parseEther('1000000');
    const prpVirtualAmount = zkpAmount.div(ethers.utils.parseUnits('1', 17));

    const placeholder = BigNumber.from(0);
    const proof = {
        a: {x: placeholder, y: placeholder},
        b: {
            x: [placeholder, placeholder],
            y: [placeholder, placeholder],
        },
        c: {x: placeholder, y: placeholder},
    } as SnarkProofStruct;
    const transactionOptions = 0x104;
    const paymasterCompensation = ethers.BigNumber.from('10');
    const zkpAmountMin = ethers.utils.parseEther('10');

    before(async () => {
        [owner, notOwner] = await ethers.getSigners();

        const ZkpToken = await ethers.getContractFactory('TokenMock');
        zkpToken = (await ZkpToken.deploy()) as TokenMock;

        feeMaster = await smock.fake('FeeMaster');
        pantherTrees = await smock.fake('IUtxoInserter');
        vault = await smock.fake('VaultV1');
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();

        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        const PrpConversion = await ethers.getContractFactory(
            'MockPrpConversion',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                },
            },
        );

        prpConversion = (await PrpConversion.connect(owner).deploy(
            pantherTrees.address,
            vault.address,
            feeMaster.address,
            zkpToken.address,
        )) as MockPrpConversion;
    });

    afterEach(async () => {
        await revertSnapshot(snapshot);
    });

    function getAmountOut(
        amountIn: BigNumber,
        reserveIn: BigNumber,
        reserveOut: BigNumber,
    ): BigNumber {
        const numerator = amountIn.mul(reserveOut);
        const denominator = reserveIn.add(amountIn);
        const amountOut = numerator.div(denominator);
        return amountOut;
    }

    describe('#deployment', () => {
        it('should set the correct panther tree address', async () => {
            expect(await prpConversion.getPantherTree()).to.equal(
                pantherTrees.address,
            );
        });
    });

    describe('#initPool', () => {
        it('should execute initPool and set the correct reserves', async () => {
            await zkpToken.transfer(prpConversion.address, zkpAmount);
            expect(
                await zkpToken.allowance(prpConversion.address, vault.address),
            ).to.be.equal(0);

            await expect(prpConversion.initPool(prpVirtualAmount, zkpAmount))
                .to.emit(prpConversion, 'Sync')
                .withArgs(prpVirtualAmount, zkpAmount)
                .and.to.emit(prpConversion, 'Initialized')
                .withArgs(prpVirtualAmount, zkpAmount);

            const reserves = await prpConversion.getReserves();
            expect(reserves._prpReserve).to.equal(prpVirtualAmount);
            expect(reserves._zkpReserve).to.equal(zkpAmount);
            expect(reserves._blockTimestampLast).to.equal(
                await getBlockTimestamp(),
            );
            expect(
                await zkpToken.allowance(prpConversion.address, vault.address),
            ).to.be.equal(zkpAmount);

            expect(await prpConversion.initialized()).to.equal(true);
        });

        it('should revert if not executed by owner ', async () => {
            await expect(
                prpConversion
                    .connect(notOwner)
                    .initPool(prpVirtualAmount, zkpAmount),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });

        it('should revert if trying to initalise already initialized pool ', async function () {
            await zkpToken.transfer(prpConversion.address, zkpAmount);
            await prpConversion.initPool(prpVirtualAmount, zkpAmount);

            await expect(
                prpConversion.initPool(prpVirtualAmount, zkpAmount),
            ).to.be.revertedWith('PC:E2');
        });

        it('should revert if zkpBalance is lesser than zkpAmount', async () => {
            await expect(
                prpConversion.initPool(prpVirtualAmount, zkpAmount),
            ).to.be.revertedWith('PC:E5');
        });
    });

    describe('#increaseZkpReserve', function () {
        beforeEach(async () => {
            await zkpToken.transfer(prpConversion.address, zkpAmount);
        });
        it('should increase zkp reserve and update allowance of vault ', async function () {
            await prpConversion.initPool(prpVirtualAmount, zkpAmount);
            expect(
                await zkpToken.allowance(prpConversion.address, vault.address),
            ).to.be.equal(zkpAmount);

            const newZkpAmount = ethers.utils.parseUnits('500', 9);
            await zkpToken.transfer(prpConversion.address, newZkpAmount);

            const prpAmountOut = await getAmountOut(
                newZkpAmount,
                zkpAmount,
                prpVirtualAmount,
            );

            await expect(prpConversion.increaseZkpReserve())
                .to.emit(prpConversion, 'Sync')
                .withArgs(
                    prpVirtualAmount.sub(prpAmountOut),
                    zkpAmount.add(newZkpAmount),
                )
                .and.to.emit(prpConversion, 'ZkpReservesIncreased')
                .withArgs(newZkpAmount);

            const reserves = await prpConversion.getReserves();
            expect(reserves._zkpReserve).to.equal(zkpAmount.add(newZkpAmount));
            expect(reserves._prpReserve).to.equal(
                prpVirtualAmount.sub(prpAmountOut),
            );
            expect(reserves._blockTimestampLast).to.equal(
                await getBlockTimestamp(),
            );
            //vault allowance should be increased
            expect(
                await zkpToken.allowance(prpConversion.address, vault.address),
            ).to.be.equal(zkpAmount.add(newZkpAmount));
        });

        it('should return if zkpBalance is less than zkpReserve', async function () {
            await prpConversion.initPool(prpVirtualAmount, zkpAmount);
            const zkpReserve = (await prpConversion.getReserves())._zkpReserve;
            const prpReserve = (await prpConversion.getReserves())._prpReserve;
            await prpConversion.testWithdrawZkp(
                zkpToken.address,
                owner.address,
                1000,
            );
            await prpConversion.increaseZkpReserve();
            expect((await prpConversion.getReserves())._zkpReserve).to.be.equal(
                zkpReserve,
            );
            expect((await prpConversion.getReserves())._prpReserve).to.be.equal(
                prpReserve,
            );
            await revertSnapshot(snapshot);
        });

        it('should revert if the pool is not initialized', async function () {
            await expect(prpConversion.increaseZkpReserve()).to.be.revertedWith(
                'PC:E3',
            );
        });
    });

    describe('convert', function () {
        beforeEach(async () => {
            await zkpToken.transfer(prpConversion.address, zkpAmount);
            await prpConversion.initPool(prpVirtualAmount, zkpAmount);
        });

        it('Should perform conversion and update reserves', async function () {
            const withdrawPrp = BigNumber.from(1000);
            const prpReserve = (await prpConversion.getReserves())._prpReserve;

            const inputs = await getPrpClaimandConversionInputs({
                withdrawPrpAmount: withdrawPrp,
            });

            const reserves = await prpConversion.getReserves();
            const zkpAmtOut = getAmountOut(
                withdrawPrp,
                reserves._prpReserve,
                reserves._zkpReserve,
            );
            const zkpAmtScaled = zkpAmtOut.div(inputs[7]);
            const zkpAmtRounded = zkpAmtScaled.mul(inputs[7]);

            await expect(
                prpConversion.convert(
                    inputs,
                    proof,
                    transactionOptions,
                    zkpAmountMin,
                    paymasterCompensation,
                    privateMessage,
                ),
            )
                .to.emit(prpConversion, 'Sync')
                .withArgs(prpReserve.add(withdrawPrp), zkpAmount)
                .and.to.emit(prpConversion, 'FeesAccounted')
                .and.to.emit(prpConversion, 'TransactionNote');

            expect((await prpConversion.getReserves())._prpReserve).to.be.equal(
                prpReserve.add(withdrawPrp),
            );
            expect(await prpConversion.internalIsSpent(inputs[8])).to.be.gt(0); //zAccountUtxoInNullifier
            expect(
                await prpConversion.internalFeeMasterDebt(zkpToken.address),
            ).to.be.equal(inputs[2]); //chargedAmountZkp

            const expectedLockData = {
                tokenType: 0,
                token: zkpToken.address,
                tokenId: BigNumber.from('0'),
                extAccount: prpConversion.address,
                extAmount: zkpAmtRounded,
            };

            expect(vault.lockAsset).to.have.been.calledOnceWith(
                expectedLockData,
            );
        });

        it('should revert if the extraInputsHash is larger than FIELD_SIZE', async function () {
            const invalidInputsHash = ethers.BigNumber.from('12345').toString();
            const inputs = await getPrpClaimandConversionInputs({
                extraInputsHash: invalidInputsHash,
            });

            await expect(
                prpConversion.convert(
                    inputs,
                    proof,
                    transactionOptions,
                    zkpAmountMin,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PIG:E4');
        });

        it('should revert if the depositPrpAmount is non zero ', async function () {
            const inputs = await getPrpClaimandConversionInputs({
                depositPrpAmount: BigNumber.from(10),
            });

            await expect(
                prpConversion.convert(
                    inputs,
                    proof,
                    transactionOptions,
                    zkpAmountMin,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PC:E14');
        });

        it('should revert if withdrawPrpAmount is zero ', async function () {
            const inputs = await getPrpClaimandConversionInputs({
                withdrawPrpAmount: BigNumber.from(0),
            });

            await expect(
                prpConversion.convert(
                    inputs,
                    proof,
                    transactionOptions,
                    zkpAmountMin,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PC:E6');
        });

        it('should revert if amountOut is less than amountOutMin  ', async function () {
            const inputs = await getPrpClaimandConversionInputs({
                withdrawPrpAmount: BigNumber.from(1),
            });

            await expect(
                prpConversion.convert(
                    inputs,
                    proof,
                    transactionOptions,
                    zkpAmountMin,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PC:E9');
        });

        it('should revert if zkpBalance and zkpReserve is not in sync  ', async function () {
            await prpConversion.testWithdrawZkp(
                zkpToken.address,
                owner.address,
                ethers.utils.parseEther('100'),
            );
            const inputs = await getPrpClaimandConversionInputs({
                withdrawPrpAmount: BigNumber.from(1000),
            });

            await expect(
                prpConversion.convert(
                    inputs,
                    proof,
                    transactionOptions,
                    zkpAmountMin,
                    paymasterCompensation,
                    privateMessage,
                ),
            ).to.be.revertedWith('PC:E11');
        });
    });
});
