// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {expect} from 'chai';
import {BigNumber, Contract} from 'ethers';
import {ethers} from 'hardhat';

import {
    getPoseidonT3Contract,
    getPoseidonT4Contract,
} from '../../lib/poseidonBuilder';
import {
    TokenMock,
    VaultV1,
    PantherVerifier,
    PoseidonT3,
    PoseidonT4,
    PantherStaticTree,
    PantherTaxiTree,
    PantherFerryTree,
    PantherBusTree,
    MockPantherPoolV1,
    FeeMaster,
} from '../../types/contracts';
import {SnarkProofStruct} from '../../types/contracts/IPantherPoolV1';

import {
    generatePrivateMessage,
    TransactionTypes,
} from './data/samples/transactionNote.data';
import {ErrorMessages} from './errMsgs/PantherPoolV1ErrMsgs';
import {getBlockTimestamp} from './helpers/hardhat';

describe.only('PantherPoolV1', function () {
    let owner: SignerWithAddress,
        zAccountRegistry: SignerWithAddress,
        prpVoucherGrantor: SignerWithAddress,
        prpConverter: SignerWithAddress,
        feeMaster: FakeContract<FeeMaster>,
        user: SignerWithAddress;
    let pantherStaticTree: FakeContract<PantherStaticTree>;
    let pantherTaxiTree: FakeContract<PantherTaxiTree>;
    let pantherBusTree: FakeContract<PantherBusTree>;
    let pantherFerryTree: FakeContract<PantherFerryTree>;
    let vault: VaultV1;
    let zkpToken: TokenMock;
    let pantherPool: MockPantherPoolV1;
    let verifier: FakeContract<PantherVerifier>;
    let poseidonT3: PoseidonT3;
    let poseidonT4: PoseidonT4;
    let vaultProxy: Contract;

    const examplePubKeys = {
        x: '11422399650618806433286579969134364085104724365992006856880595766565570395421',
        y: '1176938832872885725065086511371600479013703711997288837813773296149367990317',
    };

    before(async function () {
        [owner, zAccountRegistry, prpVoucherGrantor, prpConverter, user] =
            await ethers.getSigners();

        const ZkpToken = await ethers.getContractFactory('TokenMock');
        zkpToken = await ZkpToken.deploy();

        const PoseidonT3 = await getPoseidonT3Contract();
        poseidonT3 = (await PoseidonT3.deploy()) as PoseidonT3;

        const PoseidonT4 = await getPoseidonT4Contract();
        poseidonT4 = (await PoseidonT4.deploy()) as PoseidonT4;

        feeMaster = await smock.fake('FeeMaster', {});

        feeMaster['accountFees((uint16,uint8,uint40,uint40,uint40))'].returns({
            scMiningReward: 123,
            scKycFee: 456,
            scPaymasterCompensationInNative: 789,
            scKytFees: 0,
            protocolFee: 0,
        });

        pantherStaticTree = await smock.fake('PantherStaticTree', {});
        pantherTaxiTree = await smock.fake('PantherTaxiTree');
        pantherFerryTree = await smock.fake('PantherFerryTree');
        pantherBusTree = await smock.fake('PantherBusTree');
        verifier = await smock.fake('PantherVerifier');

        verifier.verify.returns(true);

        pantherStaticTree.getRoot.returns(
            ethers.utils.id('staticTreeMerkleRoot'),
        );

        const EIP173Proxy = await ethers.getContractFactory('EIP173Proxy');

        vaultProxy = await EIP173Proxy.deploy(
            ethers.constants.AddressZero,
            owner.address,
            [],
        );
    });

    beforeEach(async function () {
        const PantherPool = await ethers.getContractFactory(
            'MockPantherPoolV1',
            {
                libraries: {
                    'contracts/common/crypto/Poseidon.sol:PoseidonT3':
                        poseidonT3.address,
                    'contracts/common/crypto/Poseidon.sol:PoseidonT4':
                        poseidonT4.address,
                },
            },
        );

        const forestTrees = {
            taxiTree: pantherTaxiTree.address,
            busTree: pantherBusTree.address,
            ferryTree: pantherFerryTree.address,
        };

        pantherPool = await PantherPool.deploy(
            owner.address,
            zkpToken.address,
            forestTrees,
            pantherStaticTree.address,
            vaultProxy.address,
            zAccountRegistry.address,
            prpVoucherGrantor.address,
            prpConverter.address,
            feeMaster.address,
            verifier.address,
        );

        await pantherPool.deployed();

        const Vault = await ethers.getContractFactory('VaultV1');
        vault = await Vault.deploy(pantherPool.address);

        await vaultProxy.upgradeTo(vault.address);
    });

    interface CreateZAccountOptions {
        extraInputsHash?: string;
        addedAmountZkp?: number;
        chargedAmountZkp?: BigNumber;
        zAccountId?: number;
        zAccountCreateTime?: BigNumber;
        zAccountRootSpendPubKeyX?: string;
        zAccountRootSpendPubKeyY?: string;
        zAccountPubReadKeyX?: string;
        zAccountPubReadKeyY?: string;
        zAccountNullifierPubKeyX?: string;
        zAccountNullifierPubKeyY?: string;
        zAccountMasterEOA?: string;
        zAccountNullifierZone?: BigNumber;
        commitment?: string;
        kycSignedMessageHash?: string;
        staticTreeMerkleRoot?: string;
        forestMerkleRoot?: string;
        saltHash?: string;
        magicalConstraint?: string;
    }

    async function createZAccount(options: CreateZAccountOptions) {
        const placeholder = BigNumber.from(0);
        const proof = {
            a: {x: placeholder, y: placeholder},
            b: {
                x: [placeholder, placeholder],
                y: [placeholder, placeholder],
            },
            c: {x: placeholder, y: placeholder},
        } as SnarkProofStruct;

        const addedAmountZkp = options.addedAmountZkp || 0;
        const chargedAmountZkp =
            options.chargedAmountZkp || ethers.utils.parseEther('10');
        const zAccountId = options.zAccountId || 0;
        const privateMessages = generatePrivateMessage(
            TransactionTypes.zAccountActivation,
        );
        const zAccountCreateTime =
            options.zAccountCreateTime || (await getBlockTimestamp()) + 10;
        const zAccountRootSpendPubKeyX =
            options.zAccountRootSpendPubKeyX || examplePubKeys.x;
        const zAccountRootSpendPubKeyY =
            options.zAccountRootSpendPubKeyY || examplePubKeys.y;
        const zAccountPubReadKeyX =
            options.zAccountPubReadKeyX || examplePubKeys.x;
        const zAccountPubReadKeyY =
            options.zAccountPubReadKeyY || examplePubKeys.y;
        const zAccountMasterEOA = options.zAccountMasterEOA || user.address;
        const zAccountNullifierZone =
            options.zAccountNullifierZone || BigNumber.from(1);
        const zAccountNullifierPubKeyX =
            options.zAccountNullifierPubKeyX || ethers.utils.id('nullifier');
        const zAccountNullifierPubKeyY =
            options.zAccountNullifierPubKeyY || ethers.utils.id('nullifier');
        const commitment = options.commitment || ethers.utils.id('commitment');
        const kycSignedMessageHash =
            options.kycSignedMessageHash ||
            ethers.utils.id('kycSignedMessageHash');
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
        const transactionOptions = 0;
        const paymasterCompensation = ethers.BigNumber.from('10');
        const extraInput = ethers.utils.solidityPack(
            ['uint32', 'uint96', 'bytes'],
            [transactionOptions, paymasterCompensation, privateMessages],
        );
        const calculatedExtraInputHash = BigNumber.from(
            ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
        ).mod(SNARK_FIELD_SIZE);

        const extraInputsHash =
            options.extraInputsHash || calculatedExtraInputHash;

        const hexForestRoot = ethers.utils.hexlify(
            BigNumber.from(forestMerkleRoot),
        );

        await pantherPool.internalCacheNewRoot(hexForestRoot);
        await expect(
            pantherPool
                .connect(zAccountRegistry)
                .createZAccountUtxo(
                    [
                        extraInputsHash,
                        addedAmountZkp,
                        chargedAmountZkp,
                        zAccountId,
                        zAccountCreateTime,
                        zAccountRootSpendPubKeyX,
                        zAccountRootSpendPubKeyY,
                        zAccountPubReadKeyX,
                        zAccountPubReadKeyY,
                        zAccountNullifierPubKeyX,
                        zAccountNullifierPubKeyY,
                        zAccountMasterEOA,
                        zAccountNullifierZone,
                        commitment,
                        kycSignedMessageHash,
                        staticTreeMerkleRoot,
                        forestMerkleRoot,
                        saltHash,
                        magicalConstraint,
                    ],
                    proof,
                    transactionOptions,
                    0x100,
                    paymasterCompensation,
                    privateMessages,
                ),
        ).to.emit(pantherPool, 'TransactionNote');
    }

    describe('Deployment', function () {
        it('sets the correct address', async function () {
            expect(await pantherPool.OWNER()).to.equal(owner.address);
            expect(await pantherPool.VAULT()).to.equal(vaultProxy.address);
            expect(await pantherPool.STATIC_TREE()).to.equal(
                pantherStaticTree.address,
            );
            expect(await pantherPool.ZACCOUNT_REGISTRY()).to.equal(
                zAccountRegistry.address,
            );
            expect(await pantherPool.VERIFIER()).to.equal(verifier.address);

            expect(await pantherPool.PRP_VOUCHER_GRANTOR()).to.equal(
                prpVoucherGrantor.address,
            );
            expect(await pantherPool.PRP_CONVERTER()).to.equal(
                prpConverter.address,
            );
        });
    });

    describe('#createZAccountUtxo', function () {
        it('should create zAccountUtxo and increase feeMaster debt', async function () {
            expect(
                await pantherPool.feeMasterDebt(zkpToken.address),
            ).to.be.equal(BigNumber.from(0));
            await pantherPool.updateCircuitId(0x100, 1);
            await createZAccount({});
            expect(
                await pantherPool.feeMasterDebt(zkpToken.address),
            ).to.be.equal(ethers.utils.parseEther('10'));
        });

        it('should revert if circuit id is not updated ', async function () {
            await expect(createZAccount({})).to.be.revertedWith(
                ErrorMessages.ERR_UNDEFINED_CIRCUIT,
            );
        });

        it('should revert if the input values are passed as zero ', async function () {
            await pantherPool.updateCircuitId(0x100, 1);
            await expect(createZAccount({saltHash: '0'})).to.be.revertedWith(
                ErrorMessages.ERR_ZERO_SALT_HASH,
            );

            await expect(
                createZAccount({magicalConstraint: '0'}),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_MAGIC_CONSTR);

            await expect(
                createZAccount({zAccountNullifierZone: BigNumber.from(0)}),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_NULLIFIER);

            await expect(createZAccount({commitment: '0'})).to.be.revertedWith(
                ErrorMessages.ERR_ZERO_ZACCOUNT_COMMIT,
            );
            await expect(
                createZAccount({kycSignedMessageHash: '0'}),
            ).to.be.revertedWith(ErrorMessages.ERR_ZERO_KYC_MSG_HASH);
        });

        it('should revert if static tree root is not valid', async function () {
            await pantherPool.updateCircuitId(0x100, 1);
            await expect(
                createZAccount({staticTreeMerkleRoot: ethers.utils.id('root')}),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_STATIC_ROOT);
        });

        it('should revert if zAccount creation time is not valid', async function () {
            await pantherPool.updateCircuitId(0x100, 1);
            await expect(
                createZAccount({zAccountCreateTime: BigNumber.from(0)}),
            ).to.be.revertedWith(ErrorMessages.ERR_INVALID_CREATE_TIME);
        });
    });
});
