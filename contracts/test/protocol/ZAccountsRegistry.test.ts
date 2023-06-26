// SPDX-License-Identifier: MIT
import {smock, FakeContract} from '@defi-wonderland/smock';
// eslint-disable-next-line
import {TypedDataDomain} from '@ethersproject/abstract-signer';
import {Provider} from '@ethersproject/providers';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {fromRpcSig} from 'ethereumjs-util';
import {BaseContract, BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {getPoseidonT3Contract} from '../../lib/poseidonBuilder';
import {
    MockZAccountsRegistry,
    IPantherPoolV1,
    PoseidonT3,
} from '../../types/contracts';
import {SnarkProofStruct} from '../../types/contracts/IPantherPoolV1';

import {
    getBlockTimestamp,
    revertSnapshot,
    takeSnapshot,
} from './helpers/hardhat';

describe.only('ZAccountsRegistry', function () {
    let zAccountsRegistry: MockZAccountsRegistry;
    let poseidonT3: PoseidonT3;
    let pantherPool: FakeContract<IPantherPoolV1>;
    let owner: SignerWithAddress,
        notOwner: SignerWithAddress,
        user: SignerWithAddress,
        accounts: SignerWithAddress[];
    let provider: Provider;
    let zAccountVersion: number;
    let snapshot: number;

    const unusedUint216 = BigNumber.from(0);

    enum zAccountStatus {
        ACTIVATED = 1,
        DEACTIVATED = 2,
        SUSPENDED = 3,
    }

    before(async () => {
        [, owner, notOwner, user, ...accounts] = await ethers.getSigners();
        provider = ethers.provider;

        pantherPool = await smock.fake('IPantherPoolV1');

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
                    PoseidonT3: poseidonT3.address,
                },
            },
        );
        zAccountsRegistry = (await ZAccountsRegistry.connect(owner).deploy(
            pantherPool.address,
        )) as MockZAccountsRegistry;

        zAccountVersion = await zAccountsRegistry.ZACCOUNT_VERSION();
    });

    afterEach(async () => {
        await revertSnapshot(snapshot);
    });

    describe('#getNextZAccountId and #zAccountIdTracker()', () => {
        async function mockZAccountIdTracker(
            tracker: number,
        ): Promise<BigNumber> {
            await zAccountsRegistry.mockZAccountIdTracker(tracker);
            return BigNumber.from(tracker);
        }

        async function internalGetNextZAccountId(): Promise<BigNumber> {
            await zAccountsRegistry.internalGetNextZAccountId();
            return await zAccountsRegistry.nextId();
        }

        it('should get the zAccount id #1', async () => {
            const currentIdTracker = await mockZAccountIdTracker(0);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(currentIdTracker.add(1));
        });

        it('should get the zAccount id #2', async () => {
            const currentIdTracker = await mockZAccountIdTracker(1);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(currentIdTracker.add(1));
        });

        it('should get the zAccount id #252 and skip 4 numbers', async () => {
            const currentIdTracker = await mockZAccountIdTracker(251);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(256);
        });

        it('should get the zAccount id #257', async () => {
            const currentIdTracker = await mockZAccountIdTracker(256);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(currentIdTracker.add(1));
        });

        it('should get the zAccount id #258', async () => {
            const currentIdTracker = await mockZAccountIdTracker(257);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(currentIdTracker.add(1));
        });

        it('should get the zAccount id #508 and skip 4 numbers', async () => {
            const currentIdTracker = await mockZAccountIdTracker(507);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(512);
        });

        it('should get the zAccount id #513', async () => {
            const currentIdTracker = await mockZAccountIdTracker(512);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(513);
        });

        it('should get the zAccount id #514', async () => {
            const currentIdTracker = await mockZAccountIdTracker(513);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(currentIdTracker.add(1));
        });

        it('should get the zAccount id #764 and skip 4 numbers', async () => {
            const currentIdTracker = await mockZAccountIdTracker(763);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(768);
        });

        it('should get the zAccount id #769', async () => {
            const currentIdTracker = await mockZAccountIdTracker(768);

            const nextId = await internalGetNextZAccountId();
            const updatedIdTracker =
                await zAccountsRegistry.zAccountIdTracker();

            expect(nextId).to.be.eq(currentIdTracker.add(1));
            expect(updatedIdTracker).to.be.eq(currentIdTracker.add(1));
        });
    });

    async function updateBlacklistForMasterEoa(
        masterEoa: string,
        isBlacklisted: boolean,
    ): Promise<string> {
        await expect(
            zAccountsRegistry
                .connect(owner)
                .updateBlacklistForMasterEoa(masterEoa, isBlacklisted),
        )
            .to.emit(zAccountsRegistry, 'BlacklistForMasterEoaUpdated')
            .withArgs(masterEoa, isBlacklisted);

        return masterEoa;
    }

    describe('#updateBlacklistForMasterEoa', () => {
        let masterEoa: string;
        let isBlacklisted: boolean;

        beforeEach(() => {
            masterEoa = ethers.Wallet.createRandom().address;
        });

        describe('when be executed by owner', () => {
            describe('success', () => {
                it('should add blacklist', async () => {
                    isBlacklisted = true;
                    await updateBlacklistForMasterEoa(masterEoa, isBlacklisted);

                    expect(
                        await zAccountsRegistry.isMasterEoaBlacklisted(
                            masterEoa,
                        ),
                    ).to.be.true;
                });

                it('should remove blacklist', async () => {
                    isBlacklisted = false;

                    await updateBlacklistForMasterEoa(
                        masterEoa,
                        !isBlacklisted,
                    );
                    expect(
                        await zAccountsRegistry.isMasterEoaBlacklisted(
                            masterEoa,
                        ),
                    ).to.be.true;

                    await updateBlacklistForMasterEoa(masterEoa, isBlacklisted);
                    expect(
                        await zAccountsRegistry.isMasterEoaBlacklisted(
                            masterEoa,
                        ),
                    ).to.be.false;
                });
            });

            describe('failure', () => {
                it('revert when update a master EOA twice with same status', async () => {
                    isBlacklisted = true;

                    await updateBlacklistForMasterEoa(masterEoa, isBlacklisted);

                    await expect(
                        zAccountsRegistry
                            .connect(owner)
                            .updateBlacklistForMasterEoa(
                                masterEoa,
                                isBlacklisted,
                            ),
                    ).to.revertedWith('ZAR: Invalid master eoa status');
                });
            });
        });

        describe('when be executed by non-owner', () => {
            it('should revert', async () => {
                isBlacklisted = true;

                await expect(
                    zAccountsRegistry
                        .connect(notOwner)
                        .updateBlacklistForMasterEoa(masterEoa, isBlacklisted),
                ).to.revertedWith('ImmOwn: unauthorized');
            });
        });
    });

    async function updateBlacklistForPubRootSpendingKey(
        pubRootSpendingKey: string,
        isBlacklisted: boolean,
    ): Promise<string> {
        await expect(
            zAccountsRegistry
                .connect(owner)
                .updateBlacklistForPubRootSpendingKey(
                    pubRootSpendingKey,
                    isBlacklisted,
                ),
        )
            .to.emit(zAccountsRegistry, 'BlacklistForPubRootSpendingKeyUpdated')
            .withArgs(pubRootSpendingKey, isBlacklisted);

        return pubRootSpendingKey;
    }

    describe('#updateBlacklistForPubRootSpendingKey', () => {
        let pubRootSpendingKey: string;
        let isBlacklisted: boolean;

        beforeEach(async () => {
            pubRootSpendingKey = ethers.utils.id(await getBlockTimestamp());
        });

        describe('when be executed by owner', () => {
            describe('success', () => {
                it('should add blacklist', async () => {
                    isBlacklisted = true;
                    await updateBlacklistForPubRootSpendingKey(
                        pubRootSpendingKey,
                        isBlacklisted,
                    );

                    expect(
                        await zAccountsRegistry.isPubRootSpendingKeyBlacklisted(
                            pubRootSpendingKey,
                        ),
                    ).to.be.true;
                });

                it('should remove blacklist', async () => {
                    isBlacklisted = false;

                    await updateBlacklistForPubRootSpendingKey(
                        pubRootSpendingKey,
                        !isBlacklisted,
                    );
                    expect(
                        await zAccountsRegistry.isPubRootSpendingKeyBlacklisted(
                            pubRootSpendingKey,
                        ),
                    ).to.be.true;

                    await updateBlacklistForPubRootSpendingKey(
                        pubRootSpendingKey,
                        isBlacklisted,
                    );
                    expect(
                        await zAccountsRegistry.isPubRootSpendingKeyBlacklisted(
                            pubRootSpendingKey,
                        ),
                    ).to.be.false;
                });
            });

            describe('failure', () => {
                it('revert when update a master EOA twice with same status', async () => {
                    isBlacklisted = true;

                    await updateBlacklistForPubRootSpendingKey(
                        pubRootSpendingKey,
                        isBlacklisted,
                    );

                    await expect(
                        zAccountsRegistry
                            .connect(owner)
                            .updateBlacklistForPubRootSpendingKey(
                                pubRootSpendingKey,
                                isBlacklisted,
                            ),
                    ).to.revertedWith(
                        'ZAR: Invalid pub root spending key status',
                    );
                });
            });
        });

        describe('when be executed by non-owner', () => {
            it('should revert', async () => {
                isBlacklisted = true;

                await expect(
                    zAccountsRegistry
                        .connect(notOwner)
                        .updateBlacklistForPubRootSpendingKey(
                            pubRootSpendingKey,
                            isBlacklisted,
                        ),
                ).to.revertedWith('ImmOwn: unauthorized');
            });
        });
    });

    async function genSignature(
        pubRootSpendingKey: string,
        pubReadingKey: string,
        salt: string,
        signer: SignerWithAddress,
    ) {
        const name = await zAccountsRegistry.ERC712_NAME();
        const version = await zAccountsRegistry.ERC712_VERSION();
        const {chainId} = await provider.getNetwork();
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

    function getZAccountRegistrationParams() {
        const salt = ethers.utils.id('random');
        const pubRootSpendingKey = ethers.utils.id('pubRootSpendingKey');
        const pubReadingKey = ethers.utils.id('pubReadingKey');

        return {salt, pubRootSpendingKey, pubReadingKey};
    }

    async function registerZAccount(
        pubRootSpendingKey: string,
        pubReadingKey: string,
        salt: string,
        signer: SignerWithAddress,
        expectedZAccountId = 1,
    ) {
        const {v, r, s} = await genSignature(
            pubRootSpendingKey,
            pubReadingKey,
            salt,
            signer,
        );

        await expect(
            zAccountsRegistry.registerZAccount(
                pubRootSpendingKey,
                pubReadingKey,
                salt,
                v,
                r,
                s,
            ),
        )
            .to.emit(zAccountsRegistry, 'ZAccountRegistered')
            .withArgs([
                unusedUint216,
                expectedZAccountId,
                zAccountVersion,
                zAccountStatus.DEACTIVATED,
                pubRootSpendingKey,
                pubReadingKey,
            ]);
    }

    describe('#registerZAccount', () => {
        describe('Success', () => {
            it('should register zAccount when signature is correct', async () => {
                const {salt, pubRootSpendingKey, pubReadingKey} =
                    getZAccountRegistrationParams();

                const expectedZAccountId = 1;

                await registerZAccount(
                    pubRootSpendingKey,
                    pubReadingKey,
                    salt,
                    user,
                    expectedZAccountId,
                );

                expect(
                    await zAccountsRegistry.getZAccountId(user.address),
                ).to.be.eq(expectedZAccountId);

                expect(
                    await zAccountsRegistry.getZAccount(user.address),
                ).to.deep.equal([
                    unusedUint216,
                    expectedZAccountId,
                    zAccountVersion,
                    zAccountStatus.DEACTIVATED,
                    pubRootSpendingKey,
                    pubReadingKey,
                ]);
            });
        });

        describe('Failure', () => {
            it('should revert when user is already registered', async () => {
                const {salt, pubRootSpendingKey, pubReadingKey} =
                    getZAccountRegistrationParams();

                await registerZAccount(
                    pubRootSpendingKey,
                    pubReadingKey,
                    salt,
                    user,
                );

                const {v, r, s} = await genSignature(
                    pubRootSpendingKey,
                    pubReadingKey,
                    salt,
                    user,
                );

                await expect(
                    zAccountsRegistry.registerZAccount(
                        pubRootSpendingKey,
                        pubReadingKey,
                        salt,
                        v,
                        r,
                        s,
                    ),
                ).to.revertedWith('ZAR: ZAccount exists');
            });

            it('should revert when public root spending key is already blacklisted', async () => {
                const {salt, pubRootSpendingKey, pubReadingKey} =
                    getZAccountRegistrationParams();

                await updateBlacklistForPubRootSpendingKey(
                    pubRootSpendingKey,
                    true,
                );

                const {v, r, s} = await genSignature(
                    pubRootSpendingKey,
                    pubReadingKey,
                    salt,
                    user,
                );

                await expect(
                    zAccountsRegistry.registerZAccount(
                        pubRootSpendingKey,
                        pubReadingKey,
                        salt,
                        v,
                        r,
                        s,
                    ),
                ).to.revertedWith('ZAR: Blacklisted pub root spending key');
            });

            it('should revert when master eos is already blacklisted', async () => {
                await updateBlacklistForMasterEoa(user.address, true);

                const {salt, pubRootSpendingKey, pubReadingKey} =
                    getZAccountRegistrationParams();

                const {v, r, s} = await genSignature(
                    pubRootSpendingKey,
                    pubReadingKey,
                    salt,
                    user,
                );

                await expect(
                    zAccountsRegistry.registerZAccount(
                        pubRootSpendingKey,
                        pubReadingKey,
                        salt,
                        v,
                        r,
                        s,
                    ),
                ).to.revertedWith('ZAR: Blacklisted master eoa');
            });
        });
    });

    describe('#activateZAccount()', () => {
        const nullifier = ethers.utils.id('nullifier');
        const placeholder = BigNumber.from(0);

        const proof = {
            a: {x: placeholder, y: placeholder},
            b: {
                x: [placeholder, placeholder],
                y: [placeholder, placeholder],
            },
            c: {x: placeholder, y: placeholder},
        } as SnarkProofStruct;

        async function activateZAccount(user: SignerWithAddress) {
            await expect(
                zAccountsRegistry.activateZAccount(
                    user.address,
                    nullifier,
                    proof,
                ),
            )
                .to.emit(zAccountsRegistry, 'ZAccountStatusChanged')
                .withArgs(user.address, zAccountStatus.ACTIVATED);
        }

        beforeEach(async () => {
            const {salt, pubRootSpendingKey, pubReadingKey} =
                getZAccountRegistrationParams();

            await registerZAccount(
                pubRootSpendingKey,
                pubReadingKey,
                salt,
                user,
            );
        });

        describe('Success', () => {
            beforeEach(async () => {
                pantherPool.createUtxo.returns(true);
            });

            it('should activate zAccount', async () => {
                await activateZAccount(user);

                expect(
                    await zAccountsRegistry.isZAccountActivated(user.address),
                ).to.be.true;
            });
        });

        describe('Failure', () => {
            it('should revert when user has not been registered', async () => {
                const random = ethers.Wallet.createRandom().address;

                await expect(
                    zAccountsRegistry.activateZAccount(
                        random,
                        nullifier,
                        proof,
                    ),
                ).to.revertedWith('ZAR: Not exist or not deactivated');
            });

            it('should revert when activate twice', async () => {
                await activateZAccount(user);

                await expect(
                    zAccountsRegistry.activateZAccount(
                        user.address,
                        nullifier,
                        proof,
                    ),
                ).to.revertedWith('ZAR: Not exist or not deactivated');
            });

            it('should revert when pool throws error', async () => {
                pantherPool.createUtxo.returns(false);

                await expect(
                    zAccountsRegistry.activateZAccount(
                        user.address,
                        nullifier,
                        proof,
                    ),
                ).to.revertedWith('ZAR: Utxo creation failed');
            });
        });
    });

    describe('#updateBlacklistForZAccountId', () => {
        const isBlacklisted = true;

        async function getNewRoot(
            newLeaf: string,
            siblings: string[],
            proofPathIndices: string[],
        ) {
            let hash = newLeaf;
            const depth = 16;

            for (let i = 0; i < depth; i++) {
                const proofPathIndice =
                    proofPathIndices[proofPathIndices.length - 1 - i];

                if (proofPathIndice == '0') {
                    hash = await poseidonT3.poseidon([hash, siblings[i]]);
                } else {
                    hash = await poseidonT3.poseidon([siblings[i], hash]);
                }
            }

            return hash;
        }

        beforeEach(async () => {
            const {salt, pubRootSpendingKey, pubReadingKey} =
                getZAccountRegistrationParams();

            // register 2 accounts
            let expectedId = 1;
            for (const acc of accounts.slice(0, 2)) {
                await registerZAccount(
                    pubRootSpendingKey,
                    pubReadingKey,
                    salt,
                    acc,
                    expectedId,
                );
                expectedId++;
            }
        });

        it('should blacklist the account id', async () => {
            const zeroLeaf = ethers.constants.HashZero;

            const proofSiblings = [
                zeroLeaf,
                '0x2098f5fb9e239eab3ceac3f27b81e481dc3124d55ffed523a839ee8446b64864',
                '0x1069673dcdb12263df301a6ff584a7ec261a44cb9dc68df067a4774460b1f1e1',
                '0x18f43331537ee2af2e3d758d50f72106467c6eea50371dd528d57eb2b856d238',
                '0x07f9d837cb17b0d36320ffe93ba52345f1b728571a568265caac97559dbc952a',
                '0x2b94cf5e8746b3f5c9631f4c5df32907a699c58c94b2ad4d7b5cec1639183f55',
                '0x2dee93c5a666459646ea7d22cca9e1bcfed71e6951b953611d11dda32ea09d78',
                '0x078295e5a22b84e982cf601eb639597b8b0515a88cb5ac7fa8a4aabe3c87349d',
                '0x2fa5e5f18f6027a6501bec864564472a616b2e274a41211a444cbe3a99f3cc61',
                '0x0e884376d0d8fd21ecb780389e941f66e45e7acce3e228ab3e2156a614fcd747',
                '0x1b7201da72494f1e28717ad1a52eb469f95892f957713533de6175e5da190af2',
                '0x1f8d8822725e36385200c0b201249819a6e6e1e4650808b5bebc6bface7d7636',
                '0x2c5d82f66c914bafb9701589ba8cfcfb6162b0a12acf88a8d0879a0471b5f85a',
                '0x14c54148a0940bb820957f5adf3fa1134ef5c4aaa113f4646458f270e0bfbfd0',
                '0x190d33b12f986f961e10c0ee44d8b9af11be25588cad89d416118e4bf4ebe80c',
                '0x22f98aa9ce704152ac17354914ad73ed1167ae6596af510aa5b3649325e06c92',
            ];

            const decimalId_1 = 1;
            const binaryPath_1 = '0000000000000000';
            const decimalPath_1 = parseInt(binaryPath_1, 2);

            const zAccountId_1 = decimalPath_1 | decimalId_1;

            await expect(
                zAccountsRegistry.updateBlacklistForZAccountId(
                    zAccountId_1,
                    zeroLeaf,
                    proofSiblings,
                    isBlacklisted,
                ),
            )
                .to.emit(zAccountsRegistry, 'BlacklistForZAccountIdUpdated')
                .withArgs(zAccountId_1, isBlacklisted);

            const newLeaf = ethers.utils.hexZeroPad(1, 32);
            const updatedRoot_1 = await getNewRoot(
                newLeaf,
                proofSiblings,
                binaryPath_1.split(''),
            );

            expect(await zAccountsRegistry.currentRoot()).to.eq(updatedRoot_1);

            const decimalId_257 = 257;
            const binaryPath_257 = '0000000000000001';
            const decimalPath_257 = parseInt(binaryPath_1, 2);

            proofSiblings[0] = newLeaf;

            const zAccountId_257 = decimalPath_257 | decimalId_257;

            await expect(
                zAccountsRegistry.updateBlacklistForZAccountId(
                    zAccountId_257,
                    zeroLeaf,
                    proofSiblings,
                    isBlacklisted,
                ),
            )
                .to.emit(zAccountsRegistry, 'BlacklistForZAccountIdUpdated')
                .withArgs(decimalId_257, isBlacklisted);

            const updatedRoot_257 = await getNewRoot(
                newLeaf,
                proofSiblings,
                binaryPath_257.split(''),
            );

            expect(await zAccountsRegistry.currentRoot()).to.eq(
                updatedRoot_257,
            );
        });
    });
});
