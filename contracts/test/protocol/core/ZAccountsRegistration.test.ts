// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {smock, FakeContract} from '@defi-wonderland/smock';
// eslint-disable-next-line import/named
import {TypedDataDomain} from '@ethersproject/abstract-signer';
// eslint-disable-next-line import/named
import {Bytes, BytesLike} from '@ethersproject/bytes';
import {Provider} from '@ethersproject/providers';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {expect} from 'chai';
import {fromRpcSig} from 'ethereumjs-util';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {packPublicKey} from '../../../../crypto/src/base/keypairs';
import {
    generateleaf,
    generateProof,
} from '../../../lib/eip712SignatureGenerator';
import {getBlockNumber} from '../../../lib/provider';
import {
    MockZAccountsRegistration,
    PrpVoucherController,
    IUtxoInserter,
    FeeMaster,
    IERC20,
    IBlacklistedZAccountIdRegistry,
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

describe('ZAccountsRegistry', function () {
    let zAccountsRegistry: MockZAccountsRegistration;

    let zkpToken: FakeContract<IERC20>;
    let feeMaster: FakeContract<FeeMaster>;
    let pantherTrees: FakeContract<IUtxoInserter>;
    let prpVoucherController: FakeContract<PrpVoucherController>;
    let blackListRegistry: FakeContract<IBlacklistedZAccountIdRegistry>;

    let owner: SignerWithAddress,
        notOwner: SignerWithAddress,
        user: SignerWithAddress;
    let provider: Provider;
    let snapshot: number;
    let leaf: Bytes;
    let proof: Bytes[];

    const zAccountVersion = 1;

    enum Status {
        Undefined = 0,
        Registered = 1,
        Activated = 2,
    }

    const examplePubKeys = {
        x: '11422399650618806433286579969134364085104724365992006856880595766565570395421',
        y: '1176938832872885725065086511371600479013703711997288837813773296149367990317',
    };

    before(async () => {
        [, owner, notOwner, user] = await ethers.getSigners();
        provider = ethers.provider;

        zkpToken = await smock.fake('IERC20');
        feeMaster = await smock.fake('FeeMaster');
        pantherTrees = await smock.fake('IUtxoInserter');
        prpVoucherController = await smock.fake('PrpVoucherController');
        blackListRegistry = await smock.fake('IBlacklistedZAccountIdRegistry');
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();

        const ZAccountsRegistry = await ethers.getContractFactory(
            'MockZAccountsRegistration',
        );

        zAccountsRegistry = (await ZAccountsRegistry.connect(owner).deploy(
            zAccountVersion,
            prpVoucherController.address,
            pantherTrees.address,
            feeMaster.address,
            zkpToken.address,
        )) as MockZAccountsRegistration;
    });

    afterEach(async () => {
        await revertSnapshot(snapshot);
    });

    interface RegisterZAccountsOptions {
        pubRootSpendingKey?: {x: string; y: string};
        pubReadingKey?: {x: string; y: string};
        user?: SignerWithAddress;
    }

    interface ActivateZAccountOptions {
        extraInputsHash?: string;
        addedAmountZkp?: number;
        chargedAmountZkp?: number;
        zAccountId?: number;
        zAccountCreateTime?: BigNumber;
        zAccountRootSpendPubKeyX?: string;
        zAccountRootSpendPubKeyY?: string;
        zAccountPubReadKeyX?: string;
        zAccountPubReadKeyY?: string;
        zAccountNullifierPubKeyX?: string;
        zAccountNullifierPubKeyY?: string;
        zAccountMasterEOA?: string;
        zAccountNullifierZone?: string;
        commitment?: string;
        kycSignedMessageHash?: string;
        staticTreeMerkleRoot?: string;
        forestMerkleRoot?: string;
        saltHash?: string;
        magicalConstraint?: string;
    }

    async function genSignature(
        pubRootSpendingKey: string,
        pubReadingKey: string,
        signer: SignerWithAddress,
    ) {
        const name = 'Panther Protocol';
        const version = '1';
        const chainId = (await provider.getNetwork()).chainId;

        const salt: BytesLike =
            '0x44b818e3e3a12ecf805989195d8f38e75517386006719e2dbb1443987a34db7b';
        const verifyingContract = zAccountsRegistry.address;
        const zAccountVersion = await zAccountsRegistry.ZACCOUNT_VERSION();

        const types = {
            Registration: [
                {name: 'pubRootSpendingKey', type: 'bytes32'},
                {name: 'pubReadingKey', type: 'bytes32'},
                {name: 'version', type: 'uint256'},
            ],
        };

        const value = {
            pubRootSpendingKey,
            pubReadingKey,
            version: zAccountVersion,
        };

        const domain: TypedDataDomain = {
            name,
            version,
            chainId,
            verifyingContract,
            salt,
        };

        const signature = await signer._signTypedData(domain, types, value);
        return fromRpcSig(signature);
    }

    async function pointPack(point: {x: string; y: string}): Promise<string> {
        const unhexedResult = await packPublicKey([
            BigInt(point.x),
            BigInt(point.y),
        ]);
        const result = ethers.utils.hexlify(unhexedResult);
        return result;
    }

    async function registerZAccount(options: RegisterZAccountsOptions) {
        const pubRootSpendingKey = options.pubRootSpendingKey || examplePubKeys;
        const pubReadingKey = options.pubReadingKey || examplePubKeys;
        const pubRootSpendingKeyHex = await pointPack(pubRootSpendingKey);
        const pubReadingKeyHex = await pointPack(pubReadingKey);
        const inputSigner = options.user || user;

        console.log();

        const {v, r, s} = await genSignature(
            pubRootSpendingKeyHex,
            pubReadingKeyHex,
            inputSigner,
        );

        return zAccountsRegistry.registerZAccount(
            pubRootSpendingKey,
            pubReadingKey,
            v,
            r,
            s,
        );
    }

    async function activateZAccount(options: ActivateZAccountOptions) {
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
        const chargedAmountZkp = options.chargedAmountZkp || 0;
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
        const transactionOptions = 0b100000000;
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
        await expect(
            zAccountsRegistry.activateZAccount(
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
                paymasterCompensation,
                privateMessages,
            ),
        ).to.emit(zAccountsRegistry, 'ZAccountActivated');
    }

    async function generateRandomPubRootSpendingKeys(): Promise<
        [string[], {x: string; y: string}[], boolean[]]
    > {
        const blacklistedPubRootSpendingKeys = [];
        const blacklistedUnpackedKeys = [];

        for (let i = 0; i < 5; i++) {
            const blockTimestamp = await ethers.utils.id(
                getBlockTimestamp.toString(),
            );
            const xVal = ethers.BigNumber.from(blockTimestamp)
                .add(i)
                .toString();
            const yVal = ethers.BigNumber.from(blockTimestamp)
                .add(i + 10)
                .toString();
            const randomPubRootSpendingKey = {
                x: xVal,
                y: yVal,
            };
            blacklistedUnpackedKeys.push(randomPubRootSpendingKey);
            const bytesPubRootSpendingKey = await pointPack(
                randomPubRootSpendingKey,
            );
            blacklistedPubRootSpendingKeys.push(bytesPubRootSpendingKey);
        }

        const isBlacklisted = new Array(5).fill(true);
        return [
            blacklistedPubRootSpendingKeys,
            blacklistedUnpackedKeys,
            isBlacklisted,
        ];
    }

    async function generateRandomMasterEoas(): Promise<[string[], boolean[]]> {
        const blacklistedEOAs = [];
        for (let i = 0; i < 10; i++) {
            const wallet = ethers.Wallet.createRandom();
            const eoa = wallet.address;
            blacklistedEOAs.push(eoa);
        }
        const isBlacklisted = new Array(10).fill(true);
        return [blacklistedEOAs, isBlacklisted];
    }

    async function mockZAccountIdTracker(tracker: number): Promise<BigNumber> {
        await zAccountsRegistry.mockZAccountIdTracker(tracker);
        return BigNumber.from(tracker);
    }

    async function internalGetNextZAccountId(): Promise<BigNumber> {
        await zAccountsRegistry.internalGetNextZAccountId();
        return await zAccountsRegistry.nextId();
    }

    function mockGenerateRewards() {
        prpVoucherController.generateRewards.returns(100);
    }

    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    function mockFeeAccountant() {
        feeMaster['accountFees((uint16,uint8,uint40,uint40,uint40))'].returns(
            99,
        );
    }

    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    function mockUtxoInsertion() {
        pantherTrees.addUtxosToBusQueue.returns(1);
        pantherTrees.addUtxosToBusQueueAndTaxiTree.returns(1);
    }

    function mockzAcctIdBlackList() {
        blackListRegistry.addZAccountIdToBlacklist.returns(1);
        blackListRegistry.removeZAccountIdFromBlacklist.returns(1);
    }

    describe('#deployment', () => {
        it('should set the correct contract address', async () => {
            const result = await zAccountsRegistry.getSelfAndPantherTreeAddr();

            expect(result.self).to.equal(prpVoucherController.address);
            expect(result.pantherTree).to.equal(pantherTrees.address);
        });
    });

    describe('#registerZAccount', () => {
        describe('Success', () => {
            it('should register zAccount when signature is correct', async () => {
                const expectedZAccountId = 0;
                const unusedUint216 = BigNumber.from(0);
                const nextBlockNum = (await getBlockNumber()) + 1;

                await expect(await registerZAccount({}))
                    .to.emit(zAccountsRegistry, 'ZAccountRegistered')
                    .withArgs(user.address, [
                        unusedUint216,
                        nextBlockNum,
                        expectedZAccountId,
                        zAccountVersion,
                        Status.Registered,
                        await pointPack(examplePubKeys),
                        await pointPack(examplePubKeys),
                    ]);

                const zAccountStruct = await zAccountsRegistry.zAccounts(
                    user.address,
                );

                expect(zAccountStruct.id).to.be.eq(expectedZAccountId);
                expect(zAccountStruct.pubRootSpendingKey).to.be.eq(
                    await pointPack(examplePubKeys),
                );
                expect(zAccountStruct.pubReadingKey).to.be.eq(
                    await pointPack(examplePubKeys),
                );
                expect(zAccountStruct.creationBlock).to.be.eq(nextBlockNum);
                expect(zAccountStruct.version).to.be.eq(zAccountVersion);
                expect(zAccountStruct.status).to.be.eq(Status.Registered);
            });
        });

        describe('Failure', () => {
            it(`should revert when a user is already registered`, async () => {
                await registerZAccount({});

                await expect(registerZAccount({})).to.be.revertedWith('ZAR:E4');
            });

            it(`should revert if a masterEOA is blacklisted`, async () => {
                zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
                    [user.address],
                    [true],
                );

                expect(
                    await zAccountsRegistry.isMasterEoaBlacklisted(
                        user.address,
                    ),
                ).to.be.true;

                await expect(registerZAccount({})).to.be.revertedWith('ZAR:E2');
            });
        });
    });

    describe('#getNextZAccountId and #zAccountIdTracker()', () => {
        const zAccIdCounterJump = 3;
        let zAccIdTracker: number;

        it('should get the zAccount id #0 and increment Id tracker by 1', async () => {
            zAccIdTracker = 0;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #1 and increment Id tracker by 1', async () => {
            zAccIdTracker = 1;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #252 and increment Id tracker by 1', async () => {
            zAccIdTracker = 252;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #253 and skip 3 numbers', async () => {
            zAccIdTracker = 253;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(
                zAccIdTracker + zAccIdCounterJump,
            );
        });

        it('should get the zAccount id #257 and increment Id tracker by 1', async () => {
            zAccIdTracker = 257;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #258 and increment Id tracker by 1', async () => {
            zAccIdTracker = 258;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #508 and increment Id tracker by 1', async () => {
            zAccIdTracker = 508;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #509 and skip 3 numbers', async () => {
            zAccIdTracker = 509;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(
                zAccIdTracker + zAccIdCounterJump,
            );
        });

        it('should get the zAccount id #512 and increment Id tracker by 1', async () => {
            zAccIdTracker = 512;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #765 and skip 3 numbers', async () => {
            zAccIdTracker = 765;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(
                zAccIdTracker + zAccIdCounterJump,
            );
        });
    });

    describe('#activateZAccount', () => {
        describe('Success', () => {
            it('should activate zAccount if registered', async () => {
                await zAccountsRegistry.updateMaxTimeOffset(1000);

                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );

                mockGenerateRewards();

                expect(
                    await activateZAccount({
                        zAccountMasterEOA: user.address,
                    }),
                ).to.emit(zAccountsRegistry, 'ZAccountActivated');
            });
        });

        describe('Failure', () => {
            it('should revert when user has not registered the zAccount', async () => {
                await registerZAccount({});
                const wallet = ethers.Wallet.createRandom();
                const fauxUser = wallet.address;
                await expect(
                    activateZAccount({zAccountMasterEOA: fauxUser}),
                ).to.be.revertedWith('ZAR:E6');
            });

            it('should revert if the extraInputsHash is larger than FIELD_SIZE', async () => {
                await registerZAccount({});
                const invalidInputsHash =
                    ethers.BigNumber.from('12345').toString();
                await expect(
                    activateZAccount({extraInputsHash: invalidInputsHash}),
                ).to.be.revertedWith('PIG:E4');
            });

            it('should revert if a nullifier is already registered', async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                expect(
                    await activateZAccount({zAccountMasterEOA: user.address}),
                ).to.emit(zAccountsRegistry, 'ZAccountActivated');

                await expect(
                    activateZAccount({zAccountMasterEOA: user.address}),
                ).to.be.revertedWith('SN:E2');
            });

            it('should revert if public read key is not matching', async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                await expect(
                    activateZAccount({
                        zAccountPubReadKeyX: examplePubKeys.x,
                        zAccountPubReadKeyY: examplePubKeys.x,
                    }),
                ).to.be.revertedWith('ZAR:E19');
            });

            it('should revert if public root spending key is not matching', async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                await expect(
                    activateZAccount({
                        zAccountRootSpendPubKeyX: examplePubKeys.x,
                        zAccountRootSpendPubKeyY: examplePubKeys.x,
                    }),
                ).to.be.revertedWith('ZAR:E18');
            });

            it('should revert if Master EOA address is blacklisted', async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                await zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
                    [user.address],
                    [true],
                );
                await expect(
                    activateZAccount({
                        zAccountMasterEOA: user.address,
                    }),
                ).to.be.revertedWith('ZAR:E2');
            });

            it('should revert if public root spending key is blacklisted', async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                await zAccountsRegistry.batchUpdateBlacklistForPubRootSpendingKey(
                    [await pointPack(examplePubKeys)],
                    [true],
                );
                await expect(
                    activateZAccount({
                        zAccountMasterEOA: user.address,
                    }),
                ).to.be.revertedWith('ZAR:E3');
            });
        });
    });

    describe('#batchUpdateBlacklistForMasterEoa', () => {
        describe('Success', () => {
            it(`should update blacklist for a set of EOAs`, async () => {
                const [blacklistedEoas, isBlacklisted] =
                    await generateRandomMasterEoas();
                await zAccountsRegistry
                    .connect(owner)
                    .batchUpdateBlacklistForMasterEoa(
                        blacklistedEoas,
                        isBlacklisted,
                    );
                const randomEOA = blacklistedEoas[4];
                expect(
                    await zAccountsRegistry.isMasterEoaBlacklisted(randomEOA),
                ).to.be.true;
            });
        });

        describe('Failure', () => {
            it(`should revert if a blacklisted EOA attempts to register a zAccount`, async () => {
                const blacklistedEoaSigners = [];
                const blacklistedEoaStrings = [];
                const signers = await ethers.getSigners();
                for (let i = 0; i < 5; i++) {
                    const eoa = signers[i];
                    blacklistedEoaSigners.push(eoa);
                    blacklistedEoaStrings.push(eoa.address);
                }
                const isBlacklisted = new Array(5).fill(true);
                await zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
                    blacklistedEoaStrings,
                    isBlacklisted,
                );
                const blacklistedEoa = blacklistedEoaSigners[4];
                await expect(
                    registerZAccount({user: blacklistedEoa}),
                ).to.be.revertedWith('ZAR:E2');
            });

            it('should pass account registration if the EOA is not blacklisted, and fail activation if blacklisted afterwards', async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                await zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
                    [user.address],
                    [true],
                );
                await expect(
                    activateZAccount({zAccountMasterEOA: user.address}),
                ).to.be.revertedWith('ZAR:E2');
            });

            it('should revert if batchUpdate is executed by non owner', async () => {
                const [blacklistedEoas, isBlacklisted] =
                    await generateRandomMasterEoas();
                await expect(
                    zAccountsRegistry
                        .connect(notOwner)
                        .batchUpdateBlacklistForMasterEoa(
                            blacklistedEoas,
                            isBlacklisted,
                        ),
                ).to.be.revertedWith('LibDiamond: Must be contract owner');
            });

            it('should revert if the array length does not match', async () => {
                const [blacklistedEoas, isBlacklisted] =
                    await generateRandomMasterEoas();
                blacklistedEoas.push(user.address);
                await expect(
                    zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
                        blacklistedEoas,
                        isBlacklisted,
                    ),
                ).to.be.revertedWith('ZAR:E7');
            });

            it('should revert when setting the same blacklist status', async () => {
                await zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
                    [user.address],
                    [true],
                );
                await expect(
                    zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
                        [user.address],
                        [true],
                    ),
                ).to.be.revertedWith('ZAR:E8');
            });
        });
    });

    describe('#batchUpdateBlacklistForPubRootSpendingKey', () => {
        describe('Success', () => {
            it(`should update blacklist for a set of pubRootSpendingKeys`, async () => {
                const [blacklistedPubRootSpendingKeys, , isBlacklisted] =
                    await generateRandomPubRootSpendingKeys();
                expect(
                    await zAccountsRegistry.batchUpdateBlacklistForPubRootSpendingKey(
                        blacklistedPubRootSpendingKeys,
                        isBlacklisted,
                    ),
                ).to.emit(
                    zAccountsRegistry,
                    'PubRootSpendingKeyBlacklistUpdated',
                );
            });
        });

        describe('Failure', () => {
            it(`should revert if a blacklisted pubRootSpendingKey attempts to register a zAccount`, async () => {
                await zAccountsRegistry.batchUpdateBlacklistForPubRootSpendingKey(
                    [await pointPack(examplePubKeys)],
                    [true],
                );
                await expect(
                    registerZAccount({
                        pubRootSpendingKey: examplePubKeys,
                    }),
                ).to.be.revertedWith('ZAR:E3');
            });

            it(`should pass account registration if the pubRootSpendingKey is not blacklisted, and fail activation if blacklisted afterwards`, async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                await zAccountsRegistry.batchUpdateBlacklistForPubRootSpendingKey(
                    [await pointPack(examplePubKeys)],
                    [true],
                );
                expect(() =>
                    activateZAccount({zAccountMasterEOA: user.address}),
                ).to.be.revertedWith('ZAR:E3');
            });

            it('should revert if executed by non owner', async () => {
                const [blacklistedPubRootSpendingKeys, , isBlacklisted] =
                    await generateRandomPubRootSpendingKeys();
                await expect(
                    zAccountsRegistry
                        .connect(notOwner)
                        .batchUpdateBlacklistForPubRootSpendingKey(
                            blacklistedPubRootSpendingKeys,
                            isBlacklisted,
                        ),
                ).to.revertedWith('LibDiamond: Must be contract owner');
            });

            it('should revert if the array length does not match', async () => {
                const [blacklistedPubRootSpendingKeys, , isBlacklisted] =
                    await generateRandomPubRootSpendingKeys();
                blacklistedPubRootSpendingKeys.push(
                    await pointPack(examplePubKeys),
                );
                await expect(
                    zAccountsRegistry.batchUpdateBlacklistForPubRootSpendingKey(
                        blacklistedPubRootSpendingKeys,
                        isBlacklisted,
                    ),
                ).to.be.revertedWith('ZAR:E7');
            });

            it('should revert when setting the same blacklist status', async () => {
                await zAccountsRegistry.batchUpdateBlacklistForPubRootSpendingKey(
                    [await pointPack(examplePubKeys)],
                    [true],
                );
                await expect(
                    zAccountsRegistry.batchUpdateBlacklistForPubRootSpendingKey(
                        [await pointPack(examplePubKeys)],
                        [true],
                    ),
                ).to.be.revertedWith('ZAR:E8');
            });
        });
    });

    describe('#updateBlacklistForZAccountId', () => {
        before(async () => {
            mockzAcctIdBlackList();

            leaf = await generateleaf();
            proof = await generateProof(0);
        });

        describe.skip('Success', () => {
            it(`should update blacklist for ZAccountId`, async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );

                await expect(
                    zAccountsRegistry
                        .connect(owner)
                        .updateBlacklistForZAccountId(0, leaf, proof, true),
                ).to.emit(zAccountsRegistry, 'BlacklistForZAccountIdUpdated');
            });
        });

        describe('Failure', () => {
            it('should revert if executed by non owner', async () => {
                await expect(
                    zAccountsRegistry
                        .connect(notOwner)
                        .updateBlacklistForZAccountId(0, leaf, proof, true),
                ).to.be.revertedWith('LibDiamond: Must be contract owner');
            });

            it('should revert for unknown zAccountId', async () => {
                await expect(
                    zAccountsRegistry.updateBlacklistForZAccountId(
                        0,
                        leaf,
                        proof,
                        false,
                    ),
                ).to.be.revertedWith('ZAR:E6');
            });

            it('should revert for repitive status', async () => {
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                await expect(
                    zAccountsRegistry.updateBlacklistForZAccountId(
                        0,
                        leaf,
                        proof,
                        false,
                    ),
                ).to.be.revertedWith('ZAR:E8');
            });
        });
    });

    describe('#View Functions', () => {
        it(`should return true if zAccount is not blacklisted`, async () => {
            await registerZAccount({});
            expect(await zAccountsRegistry.isZAccountWhitelisted(user.address))
                .to.be.true;
        });

        it(`should return false if zAccount is blacklisted`, async () => {
            zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
                [user.address],
                [true],
            );
            expect(await zAccountsRegistry.isZAccountWhitelisted(user.address))
                .to.be.false;
        });

        it(`should return false if zAccount does not exist`, async () => {
            expect(await zAccountsRegistry.isZAccountWhitelisted(user.address))
                .to.be.false;
        });

        it(`should check if the public key is acceptable`, async () => {
            expect(await zAccountsRegistry.isAcceptablePubKey(examplePubKeys))
                .to.be.true;
        });
    });
});
