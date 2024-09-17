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

describe('PrpConversion', function () {
    let prpConversion: MockPrpConversion;

    let zkpToken: TokenMock;
    let feeMaster: FakeContract<FeeMaster>;
    let pantherTrees: FakeContract<IUtxoInserter>;
    let vault: FakeContract<VaultV1>;

    let owner: SignerWithAddress, notOwner: SignerWithAddress;
    let snapshot: number;

    const examplePubKeys = {
        x: '11422399650618806433286579969134364085104724365992006856880595766565570395421',
        y: '1176938832872885725065086511371600479013703711997288837813773296149367990317',
    };
    const privateMessage = generatePrivateMessage(
        TransactionTypes.prpConversion,
    );
    const prpVirtualAmount = ethers.utils.parseUnits('1000', 6); // Reduced precision to fit in 64-bit
    const zkpAmount = ethers.utils.parseUnits('500', 9); // Reduced precision to fit in 96-bit

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

    interface inputs {
        extraInputsHash?: string;
        addedAmountZkp?: number;
        chargedAmountZkp?: number;
        utxoOutCreateTime?: BigNumber;
        depositPrpAmount?: BigNumber;
        withdrawPrpAmount?: BigNumber;
        utxoCommitmentPrivatePart?: string;
        utxoSpendPubKeyX?: string;
        utxoSpendPubKeyY?: string;
        zAssetScale?: number;
        zAccountUtxoInNullifier?: string;
        zAccountUtxoOutCommitment?: string;
        zNetworkChainId?: number;
        staticTreeMerkleRoot?: string;
        forestMerkleRoot?: string;
        saltHash?: string;
        magicalConstraint?: string;
    }

    async function convert(options: inputs) {
        const placeholder = BigNumber.from(0);
        const proof = {
            a: {x: placeholder, y: placeholder},
            b: {
                x: [placeholder, placeholder],
                y: [placeholder, placeholder],
            },
            c: {x: placeholder, y: placeholder},
        } as SnarkProofStruct;

        const addedAmountZkp = options.addedAmountZkp || BigNumber.from(0);
        const chargedAmountZkp = options.chargedAmountZkp || BigNumber.from(0);
        const depositPrpAmount = options.depositPrpAmount || BigNumber.from(0);
        const withdrawPrpAmount =
            options.withdrawPrpAmount || BigNumber.from(10);
        const utxoCommitmentPrivatePart = 0;
        const privateMessages = privateMessage;
        const zAccountCreateTime =
            options.utxoOutCreateTime || (await getBlockTimestamp()) + 10;
        const utxoSpendPubKeyX = options.utxoSpendPubKeyX || examplePubKeys.x;
        const utxoSpendPubKeyY = options.utxoSpendPubKeyY || examplePubKeys.y;
        const zAssetScale = options.zAssetScale || 1000;
        const zNetworkChainId = 31337;
        const zAccountUtxoInNullifier =
            options.zAccountUtxoInNullifier || BigNumber.from(1);
        const zAccountUtxoOutCommitment =
            options.zAccountUtxoOutCommitment ||
            ethers.utils.id('zAccountUtxoOutCommitment');
        const staticTreeMerkleRoot =
            options.staticTreeMerkleRoot ||
            ethers.utils.id('staticTreeMerkleRoot');
        const forestMerkleRoot =
            options.forestMerkleRoot || ethers.utils.id('forestMerkleRoot');
        const saltHash =
            options.saltHash ||
            ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('PANTHER_EIP712_DOMAIN_SALT'),
            );
        const magicalConstraint =
            options.magicalConstraint || ethers.utils.id('magicalConstraint');
        const transactionOptions = 0x104;
        const paymasterCompensation = ethers.BigNumber.from('10');
        const zkpAmountMin = 10000;
        const extraInput = ethers.utils.solidityPack(
            ['uint32', 'uint96', 'uint96', 'bytes'],
            [
                transactionOptions,
                zkpAmountMin,
                paymasterCompensation,
                privateMessages,
            ],
        );
        const calculatedExtraInputHash = BigNumber.from(
            ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
        ).mod(SNARK_FIELD_SIZE);

        const extraInputsHash =
            options.extraInputsHash || calculatedExtraInputHash;

        await expect(
            prpConversion.convert(
                [
                    extraInputsHash,
                    addedAmountZkp,
                    chargedAmountZkp,
                    zAccountCreateTime,
                    depositPrpAmount,
                    withdrawPrpAmount,
                    utxoCommitmentPrivatePart,
                    utxoSpendPubKeyX,
                    utxoSpendPubKeyY,
                    zAssetScale,
                    zAccountUtxoInNullifier,
                    zAccountUtxoOutCommitment,
                    zNetworkChainId,
                    staticTreeMerkleRoot,
                    forestMerkleRoot,
                    saltHash,
                    magicalConstraint,
                ],
                proof,
                transactionOptions,
                zkpAmountMin,
                paymasterCompensation,
                privateMessages,
            ),
        ).to.emit(prpConversion, 'Sync');
    }

    describe('#deployment', () => {
        it('should set the correct panther tree address', async () => {
            expect(await prpConversion.PANTHER_TREES()).to.equal(
                pantherTrees.address,
            );
        });
    });

    describe('#initPool', () => {
        it('should execute initPool', async () => {
            await zkpToken.transfer(prpConversion.address, zkpAmount);

            await expect(prpConversion.initPool(prpVirtualAmount, zkpAmount))
                .to.emit(prpConversion, 'Initialized')
                .withArgs(prpVirtualAmount, zkpAmount);

            const reserves = await prpConversion.getReserves();
            expect(reserves._prpReserve).to.equal(prpVirtualAmount);
            expect(reserves._zkpReserve).to.equal(zkpAmount);

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
        it('should increase zkp reserve  ', async function () {
            await prpConversion.initPool(prpVirtualAmount, zkpAmount);

            const newZkpAmount = ethers.utils.parseUnits('500', 9);
            await zkpToken.transfer(prpConversion.address, newZkpAmount);

            await expect(prpConversion.increaseZkpReserve()).to.emit(
                prpConversion,
                'Sync',
            );
            const reserves = await prpConversion.getReserves();
            expect(reserves._zkpReserve).to.equal(zkpAmount.add(newZkpAmount));
        });

        it('should return if zkpBalance is less than zkpReserve', async function () {
            await prpConversion.initPool(prpVirtualAmount, zkpAmount);
            const zkpReserve = (await prpConversion.getReserves())._zkpReserve;
            const prpReserve = (await prpConversion.getReserves())._prpReserve;
            await prpConversion.rescueErc20(
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

            await convert({
                withdrawPrpAmount: withdrawPrp,
            });

            await expect(
                (await prpConversion.getReserves())._prpReserve,
            ).to.be.equal(prpReserve.add(withdrawPrp));
        });

        it('should revert if the extraInputsHash is larger than FIELD_SIZE', async function () {
            const invalidInputsHash = ethers.BigNumber.from('12345').toString();
            await expect(
                convert({extraInputsHash: invalidInputsHash}),
            ).to.be.revertedWith('PIG:E1');
        });

        it('should revert if the depositPrpAmount is non zero ', async function () {
            await expect(
                convert({depositPrpAmount: BigNumber.from(10)}),
            ).to.be.revertedWith('PC:E14');
        });

        it('should revert if withdrawPrpAmount is zero ', async function () {
            await expect(
                convert({withdrawPrpAmount: BigNumber.from(0)}),
            ).to.be.revertedWith('PC:E6');
        });

        it('should revert if amountOut is less than amountOutMin  ', async function () {
            await expect(
                convert({withdrawPrpAmount: BigNumber.from(1)}),
            ).to.be.revertedWith('PC:E7');
        });

        it('should revert if amountOut is less than zAsset Scale  ', async function () {
            await expect(
                convert({
                    zAssetScale: 10000,
                    withdrawPrpAmount: BigNumber.from(1),
                }),
            ).to.be.revertedWith('PC:E7');
        });

        it('should revert if zkpBalance and zkpReserve is not in sync  ', async function () {
            await prpConversion.rescueErc20(
                zkpToken.address,
                owner.address,
                100000,
            );
            await expect(convert({})).to.be.revertedWith('PC:E9');
        });
    });

    describe('rescueERC20', function () {
        it('Should transfer token from prpConverter', async function () {
            await zkpToken.transfer(prpConversion.address, zkpAmount);
            await prpConversion.rescueErc20(
                zkpToken.address,
                owner.address,
                1000,
            );
        });

        it('Should revert if not executed by owner', async function () {
            await expect(
                prpConversion
                    .connect(notOwner)
                    .rescueErc20(zkpToken.address, owner.address, 1000),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });
});
