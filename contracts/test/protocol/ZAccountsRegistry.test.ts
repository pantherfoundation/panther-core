// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {smock, FakeContract} from '@defi-wonderland/smock';
// eslint-disable-next-line
import {TypedDataDomain} from '@ethersproject/abstract-signer';
import {Provider} from '@ethersproject/providers';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {expect} from 'chai';
import {fromRpcSig} from 'ethereumjs-util';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {packPublicKey} from '../../../crypto/src/base/keypairs';
import {getPoseidonT3Contract} from '../../lib/poseidonBuilder';
import {
    MockZAccountsRegistry,
    IPantherPoolV1,
    IOnboardingController,
    PantherStaticTree,
    PoseidonT3,
} from '../../types/contracts';
import {SnarkProofStruct} from '../../types/contracts/IPantherPoolV1';

import {
    getBlockTimestamp,
    revertSnapshot,
    takeSnapshot,
} from './helpers/hardhat';

describe('ZAccountsRegistry', function () {
    let zAccountsRegistry: MockZAccountsRegistry;
    let poseidonT3: PoseidonT3;
    let pantherPool: FakeContract<IPantherPoolV1>;
    let pantherStaticTree: FakeContract<PantherStaticTree>;
    let onboardingRewardController: FakeContract<IOnboardingController>;
    let owner: SignerWithAddress,
        notOwner: SignerWithAddress,
        user: SignerWithAddress;
    // accounts: SignerWithAddress[];
    let provider: Provider;
    let snapshot: number;
    let zAccountVersion: number;

    const examplePubKeys = {
        x: '11422399650618806433286579969134364085104724365992006856880595766565570395421',
        y: '1176938832872885725065086511371600479013703711997288837813773296149367990317',
    };

    before(async () => {
        [, owner, notOwner, user] = await ethers.getSigners();
        provider = ethers.provider;

        pantherPool = await smock.fake('IPantherPoolV1');
        pantherStaticTree = await smock.fake('PantherStaticTree');
        onboardingRewardController = await smock.fake('IOnboardingController');

        const PoseidonT3 = await getPoseidonT3Contract();
        poseidonT3 = (await PoseidonT3.deploy()) as PoseidonT3;
        await poseidonT3.deployed();
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();

        const ZAccountsRegistry = await ethers.getContractFactory(
            'MockZAccountsRegistry',
            {
                libraries: {
                    'contracts/protocol/crypto/Poseidon.sol:PoseidonT3':
                        poseidonT3.address,
                },
            },
        );

        zAccountsRegistry = (await ZAccountsRegistry.connect(owner).deploy(
            1,
            pantherPool.address,
            pantherStaticTree.address,
            onboardingRewardController.address,
        )) as MockZAccountsRegistry;

        zAccountVersion = await zAccountsRegistry.ZACCOUNT_VERSION();
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
        zkpAmount?: number;
        zkpChange?: number;
        zAccountId?: number;
        zAccountPrpAmount?: number;
        zAccountCreateTime?: BigNumber;
        zAccountRootSpendPubKeyX?: string;
        zAccountRootSpendPubKeyY?: string;
        zAccountMasterEOA?: string;
        nullifier?: string;
        commitment?: string;
        kycSignedMessageHash?: string;
        forestMerkleRoot?: string;
        saltHash?: string;
        magicalConstraint?: string;
        placeholder?: string;
        privateMessages?: string;
    }

    async function genSignature(
        pubRootSpendingKey: string,
        pubReadingKey: string,
        signer: SignerWithAddress,
    ) {
        const name = await zAccountsRegistry.EIP712_NAME();
        const version = await zAccountsRegistry.EIP712_VERSION();
        const chainId = (await provider.getNetwork()).chainId;

        const salt = await zAccountsRegistry.EIP712_SALT();
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

        const {v, r, s} = await genSignature(
            pubRootSpendingKeyHex,
            pubReadingKeyHex,
            inputSigner,
        );

        await zAccountsRegistry.registerZAccount(
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
        const cachedForestRootIndex = 0;

        const zkpAmount = options.zkpAmount || 0;
        const zkpChange = options.zkpChange || 0;
        const zAccountId = options.zAccountId || 0;
        const privateMessages =
            ethers.utils.formatBytes32String('privateMessages');
        const zAccountPrpAmount = options.zAccountPrpAmount || 0;
        const zAccountCreateTime =
            options.zAccountCreateTime || BigNumber.from(0);
        const zAccountRootSpendPubKeyX =
            options.zAccountRootSpendPubKeyX || examplePubKeys.x;
        const zAccountRootSpendPubKeyY =
            options.zAccountRootSpendPubKeyY || examplePubKeys.y;
        const zAccountMasterEOA = options.zAccountMasterEOA || user.address;
        const nullifier = options.nullifier || ethers.utils.id('nullifier');
        const commitment = options.commitment || ethers.utils.id('commitment');
        const kycSignedMessageHash =
            options.kycSignedMessageHash ||
            ethers.utils.id('kycSignedMessageHash');
        const forestMerkleRoot =
            options.forestMerkleRoot || ethers.utils.id('forestMerkleRoot');
        const saltHash =
            options.saltHash ||
            ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('PANTHER_EIP712_DOMAIN_SALT'),
            );
        const magicalConstraint =
            options.magicalConstraint || ethers.utils.id('magicalConstraint');

        const extraInput = ethers.utils.solidityPack(
            ['bytes', 'uint256'],
            [privateMessages, cachedForestRootIndex],
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
                    zkpAmount,
                    zkpChange,
                    zAccountId,
                    zAccountPrpAmount,
                    zAccountCreateTime,
                    zAccountRootSpendPubKeyX,
                    zAccountRootSpendPubKeyY,
                    zAccountMasterEOA,
                    nullifier,
                    commitment,
                    kycSignedMessageHash,
                    forestMerkleRoot,
                    saltHash,
                    magicalConstraint,
                ],
                privateMessages,
                proof,
                cachedForestRootIndex,
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

    describe('#registerZAccount', () => {
        describe('Success', () => {
            it('should register zAccount when signature is correct', async () => {
                const unusedUint216 = BigNumber.from(0);
                const expectedZAccountId = 0;
                expect(await registerZAccount({}))
                    .to.emit(zAccountsRegistry, 'ZAccountRegistered')
                    .withArgs(user.address, [
                        unusedUint216,
                        4,
                        0,
                        zAccountVersion,
                        await pointPack(examplePubKeys),
                        await pointPack(examplePubKeys),
                    ]);

                const zAccountStruct = await zAccountsRegistry.zAccounts(
                    user.address,
                );
                expect(zAccountStruct.id).to.be.eq(expectedZAccountId);
                expect(zAccountVersion).to.be.eq(1);
                expect(zAccountStruct.pubRootSpendingKey).to.be.eq(
                    await pointPack(examplePubKeys),
                );
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
        const zAccIdCounterJump = 2;
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

        it('should get the zAccount id #253 and increment Id tracker by 1', async () => {
            zAccIdTracker = 253;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #254 and skip 2 numbers', async () => {
            zAccIdTracker = 254;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(
                zAccIdTracker + zAccIdCounterJump,
            );
        });

        it('should get the zAccount id #256 and increment Id tracker by 1', async () => {
            zAccIdTracker = 256;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #257 and increment Id tracker by 1', async () => {
            zAccIdTracker = 257;

            await mockZAccountIdTracker(257);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #509 and increment Id tracker by 1', async () => {
            zAccIdTracker = 509;

            await mockZAccountIdTracker(zAccIdTracker);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(zAccIdTracker);
            expect(updatedIdTracker).to.be.eq(zAccIdTracker + 1);
        });

        it('should get the zAccount id #510 and skip 2 numbers', async () => {
            zAccIdTracker = 510;

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

        it('should get the zAccount id #766 and skip 2 numbers', async () => {
            zAccIdTracker = 766;

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
                expect(await registerZAccount({})).to.emit(
                    zAccountsRegistry,
                    'ZAccountRegistered',
                );
                expect(
                    await activateZAccount({zAccountMasterEOA: user.address}),
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
                ).to.be.revertedWith('ZAR:E11');
            });
            it('should revert if non-zero zkpChange is supplied with tx', async () => {
                await registerZAccount({});
                await expect(
                    activateZAccount({zkpChange: 1}),
                ).to.be.revertedWith('ZAR:E16');
            });
            it('should revert if PRP is supplied with tx', async () => {
                await registerZAccount({});
                await expect(
                    activateZAccount({zAccountPrpAmount: 1}),
                ).to.be.revertedWith('ZAR:E13');
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
                ).to.be.revertedWith('ZAR:E5');
            });
            it('should revert is zkpAmount is not available for this user', async () => {
                expect(await registerZAccount({}))
                    .to.emit(onboardingRewardController, 'ZzkpAndPrpAllocated')
                    .withArgs(user.address, 1, 0);
                await expect(
                    activateZAccount({zkpAmount: 2}),
                ).to.be.revertedWith('ZAR:E12');
            });
        });
    });

    describe('#batchUpdateBlacklistForMasterEoa', () => {
        describe('Success', () => {
            it(`should update blacklist for a set of EOAs`, async () => {
                const [blacklistedEoas, isBlacklisted] =
                    await generateRandomMasterEoas();
                await zAccountsRegistry.batchUpdateBlacklistForMasterEoa(
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
                expect(() =>
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
                ).to.be.revertedWith('ImmOwn: unauthorized');
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
                const [
                    blacklistedPubRootSpendingKeys,
                    blacklistedUnpackedKeys,
                    isBlacklisted,
                ] = await generateRandomPubRootSpendingKeys();
                await zAccountsRegistry.batchUpdateBlacklistForPubRootSpendingKey(
                    blacklistedPubRootSpendingKeys,
                    isBlacklisted,
                );
                const randomPubRootSpendingKey = blacklistedUnpackedKeys[2];
                await expect(
                    registerZAccount({
                        pubRootSpendingKey: randomPubRootSpendingKey,
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
                ).to.revertedWith('ImmOwn: unauthorized');
            });
        });
    });
});
