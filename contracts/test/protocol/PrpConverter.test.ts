// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {expect} from 'chai';
import {BigNumber, ContractFactory} from 'ethers';
import {ethers} from 'hardhat';

import {
    PrpConverter,
    MockPantherPoolandPrpConverter,
    TokenMock,
    VaultV1,
} from '../../types/contracts';
import {SnarkProofStruct} from '../../types/contracts/IPantherPoolV1';

import {revertSnapshot, takeSnapshot} from './helpers/hardhat';

describe('PrpConverter', function () {
    let owner: SignerWithAddress;
    let notOwner: SignerWithAddress;
    let prpConverter: PrpConverter;
    let pantherPool: MockPantherPoolandPrpConverter;
    let zkpToken: TokenMock;
    let vault: VaultV1;
    let snapshot: number;
    let PrpConverter: ContractFactory;

    const prpVirtualAmount = ethers.utils.parseUnits('1000', 6); // Reduced precision to fit in 64-bit
    const zkpAmount = ethers.utils.parseUnits('500', 9); // Reduced precision to fit in 96-bit

    const examplePubKeys = {
        x: '11422399650618806433286579969134364085104724365992006856880595766565570395421',
        y: '1176938832872885725065086511371600479013703711997288837813773296149367990317',
    };

    before(async function () {
        [owner, notOwner] = await ethers.getSigners();

        const ZkpToken = await ethers.getContractFactory('TokenMock');
        zkpToken = await ZkpToken.deploy();

        const PantherPool = await ethers.getContractFactory(
            'MockPantherPoolandPrpConverter',
        );
        pantherPool = await PantherPool.deploy(owner.address, zkpToken.address);

        const Vault = await ethers.getContractFactory('VaultV1');
        vault = (await Vault.deploy(pantherPool.address)) as VaultV1;

        PrpConverter = await ethers.getContractFactory('PrpConverter');
        prpConverter = (await PrpConverter.deploy(
            owner.address,
            zkpToken.address,
            pantherPool.address,
            vault.address,
        )) as PrpConverter;
        await prpConverter.deployed();

        await pantherPool.updatePrpConverterandVault(
            prpConverter.address,
            vault.address,
        );
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();
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
        const privateMessages =
            ethers.utils.formatBytes32String('privateMessages');
        const zAccountCreateTime =
            options.utxoOutCreateTime || BigNumber.from(0);
        const utxoSpendPubKeyX = options.utxoSpendPubKeyX || examplePubKeys.x;
        const utxoSpendPubKeyY = options.utxoSpendPubKeyY || examplePubKeys.y;
        const zAssetScale = options.zAssetScale || 1000;
        const zNetworkChainId = 1;
        const zAccountUtxoInNullifier =
            options.zAccountUtxoInNullifier || BigNumber.from(0);
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
            prpConverter.convert(
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
        ).to.emit(prpConverter, 'Sync');
    }

    function getAmountOutRounded(
        amountIn: BigNumber,
        reserveIn: BigNumber,
        reserveOut: BigNumber,
        scale: BigNumber,
    ): BigNumber {
        const numerator = amountIn.mul(reserveOut);
        const denominator = reserveIn.add(amountIn);
        const amountOut = numerator.div(denominator);

        // Rounding the amount
        const roundedAmountOut = amountOut.div(scale).mul(scale);
        return roundedAmountOut;
    }

    describe('deployment', function () {
        it('should set the correct owner address', async function () {
            expect(await prpConverter.OWNER()).to.equal(owner.address);
        });

        it('should set the correct pool and vault addresses', async function () {
            expect(await prpConverter.PANTHER_POOL()).to.equal(
                pantherPool.address,
            );
            expect(await prpConverter.VAULT()).to.equal(vault.address);
        });

        it('Should revert for zero address', async function () {
            await expect(
                PrpConverter.deploy(
                    owner.address,
                    ethers.constants.AddressZero,
                    pantherPool.address,
                    vault.address,
                ),
            ).to.be.revertedWith('PC:E1');

            await expect(
                PrpConverter.deploy(
                    owner.address,
                    zkpToken.address,
                    ethers.constants.AddressZero,
                    vault.address,
                ),
            ).to.be.revertedWith('PC:E1');

            await expect(
                PrpConverter.deploy(
                    owner.address,
                    zkpToken.address,
                    pantherPool.address,
                    ethers.constants.AddressZero,
                ),
            ).to.be.revertedWith('PC:E1');
        });
    });

    describe('initialization', function () {
        it('should initialize ', async function () {
            await zkpToken.transfer(prpConverter.address, zkpAmount);

            await prpConverter.initPool(prpVirtualAmount, zkpAmount);

            const reserves = await prpConverter.getReserves();
            expect(reserves._prpReserve).to.equal(prpVirtualAmount);
            expect(reserves._zkpReserve).to.equal(zkpAmount);

            expect(await prpConverter.initialized()).to.equal(true);
        });

        it('should revert if not executed by owner ', async function () {
            await expect(
                prpConverter
                    .connect(notOwner)
                    .initPool(prpVirtualAmount, zkpAmount),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('should revert if trying to initalise already initialized pool ', async function () {
            await expect(
                prpConverter.initPool(prpVirtualAmount, zkpAmount),
            ).to.be.revertedWith('PC:E2');
        });

        it('should revert if zkpBalance is lesser than zkpAmount ', async function () {
            const PrpConverter =
                await ethers.getContractFactory('PrpConverter');

            const prpConverter = (await PrpConverter.deploy(
                owner.address,
                zkpToken.address,
                pantherPool.address,
                vault.address,
            )) as PrpConverter;

            await expect(
                prpConverter.initPool(prpVirtualAmount, zkpAmount),
            ).to.be.revertedWith('PC:E5');

            await revertSnapshot(snapshot);
        });
    });

    describe('increaseZkpReserve', function () {
        it('should increase zkp reserve  ', async function () {
            const newZkpAmount = ethers.utils.parseUnits('500', 9);
            await zkpToken.transfer(prpConverter.address, newZkpAmount);

            await expect(prpConverter.increaseZkpReserve()).to.emit(
                prpConverter,
                'Sync',
            );
            const reserves = await prpConverter.getReserves();
            expect(reserves._zkpReserve).to.equal(zkpAmount.add(newZkpAmount));
        });

        it('should return if zkpBalance is less than zkpReserve', async function () {
            const zkpReserve = (await prpConverter.getReserves())._zkpReserve;
            const prpReserve = (await prpConverter.getReserves())._prpReserve;
            await prpConverter.rescueErc20(
                zkpToken.address,
                owner.address,
                1000,
            );
            await expect(prpConverter.increaseZkpReserve());
            expect((await prpConverter.getReserves())._zkpReserve).to.be.equal(
                zkpReserve,
            );
            expect((await prpConverter.getReserves())._prpReserve).to.be.equal(
                prpReserve,
            );
            await revertSnapshot(snapshot);
        });

        it('should revert if the pool is not initialized', async function () {
            const PrpConverter =
                await ethers.getContractFactory('PrpConverter');

            const prpConverter = (await PrpConverter.deploy(
                owner.address,
                zkpToken.address,
                pantherPool.address,
                vault.address,
            )) as PrpConverter;

            await expect(prpConverter.increaseZkpReserve()).to.be.revertedWith(
                'PC:E3',
            );
        });
    });

    describe('convert', function () {
        it('Should perform conversion and update reserves', async function () {
            const withdrawPrp = BigNumber.from(1000);
            const prpReserve = (await prpConverter.getReserves())._prpReserve;
            const zkpReserve = (await prpConverter.getReserves())._zkpReserve;
            const zkpBalance = await zkpToken.balanceOf(prpConverter.address);

            await convert({
                withdrawPrpAmount: withdrawPrp,
            });

            const roundedAmountOut = getAmountOutRounded(
                withdrawPrp,
                prpReserve,
                zkpReserve,
                BigNumber.from(1000),
            );

            await expect(
                (await prpConverter.getReserves())._prpReserve,
            ).to.be.equal(prpReserve.add(withdrawPrp));
            await expect(
                (await prpConverter.getReserves())._zkpReserve,
            ).to.be.equal(zkpReserve.sub(roundedAmountOut));
            expect(await zkpToken.balanceOf(prpConverter.address)).to.be.equal(
                zkpBalance.sub(roundedAmountOut),
            );
        });

        it('should revert if the extraInputsHash is larger than FIELD_SIZE', async function () {
            const invalidInputsHash = ethers.BigNumber.from('12345').toString();
            await expect(
                convert({extraInputsHash: invalidInputsHash}),
            ).to.be.revertedWith('PC:E13');
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
            ).to.be.revertedWith('PC:E9');
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
            await prpConverter.rescueErc20(
                zkpToken.address,
                owner.address,
                100000,
            );
            await expect(convert({})).to.be.revertedWith('PC:E11');
        });
    });

    describe('rescueERC20', function () {
        it('Should transfer token from prpConverter', async function () {
            await prpConverter.rescueErc20(
                zkpToken.address,
                owner.address,
                1000,
            );
        });

        it('Should revert if not executed by owner', async function () {
            await expect(
                prpConverter
                    .connect(notOwner)
                    .rescueErc20(zkpToken.address, owner.address, 1000),
            ).to.be.revertedWith('PC:E12');
        });
    });
});
