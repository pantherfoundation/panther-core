// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

//TODO: enable eslint
/* eslint-disable */

import {FakeContract, smock} from '@defi-wonderland/smock';
import {BigNumberish} from '@ethersproject/bignumber/src.ts';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {
    genSignatureForRegisterProviderKey,
    genSignatureForExtendKeyRing,
    genSignatureForupdateKeyRingOperator,
    genSignatureForRevokeProviderKey,
    generateProof,
    getKeyCommitment,
    calcNewRoot,
} from '../../../lib/eip712SignatureGenerator';
import {MockProvidersKeysRegistry, StaticTree} from '../../../types/contracts';

import {
    getPoseidonT3Contract,
    getPoseidonT4Contract,
} from '.././../../lib/poseidonBuilder';
import {
    revertSnapshot,
    takeSnapshot,
    getBlockTimestamp,
} from '.././helpers/hardhat';

describe('ProvidersKeys contract', function () {
    this.timeout('100000000000');
    let providersKeys: MockProvidersKeysRegistry;
    let staticTree: FakeContract<StaticTree>;
    let owner: SignerWithAddress;
    let signer: SignerWithAddress;
    let operator: SignerWithAddress;
    let expiryDate: number;
    let newExpiryDate: number;
    let invalidExpiry: number;
    let pubKey: G1PointStruct;
    let pubKeyPacked: any;
    let keyRingId: number;
    let snapshot: number;

    type G1PointStruct = {x: string; y: string};

    before(async () => {
        pubKey = {
            x: '9487832625653172027749782479736182284968410276712116765581383594391603612850',
            y: '20341243520484112812812126668555427080517815150392255522033438580038266039458',
        };
        pubKeyPacked =
            '0x2cf8bc5fc9c122f6cc883988fd57e45ad086ec2785d2dfbfa85032373f90aca2';
        expiryDate = 1893436200; //Jan 1, 2030
        newExpiryDate = 1935689800;
        invalidExpiry = 1708006666;

        [owner, signer, operator] = await ethers.getSigners();

        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        const PoseidonT4 = await getPoseidonT4Contract();
        const poseidonT4 = await PoseidonT4.deploy();
        await poseidonT4.deployed();

        staticTree = await smock.fake('StaticTree');

        const ProvidersKeys = await ethers.getContractFactory(
            'MockProvidersKeysRegistry',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                    PoseidonT4: poseidonT4.address,
                },
            },
        );
        providersKeys = (await ProvidersKeys.deploy(
            staticTree.address,
            1,
        )) as MockProvidersKeysRegistry;

        // mock static tree
        staticTree.updateStaticRoot.returns();
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();
    });

    it('should get the zero root', async () => {
        const zeroRoot =
            '0x0a5e5ec37bd8f9a21a1c2192e7c37d86bf975d947c2b38598b00babe567191c9';
        const root = await providersKeys.getProvidersKeysRoot();
        expect(zeroRoot).to.be.eq(root);
    });

    describe('add keyring', function () {
        it('should add Keyring for a provider', async () => {
            const mockAllocKeys: BigNumberish = 100;
            await providersKeys.addKeyring(owner.address, mockAllocKeys);
            const events = await providersKeys.queryFilter('KeyringUpdated');
            keyRingId = events[0].args.keyringId;
            expect(keyRingId.toString()).equals('1');

            const statistics = await providersKeys.getStatistics();
            expect(statistics.numKeyrings).to.be.equals(1);
            expect(statistics.totalNumAllocatedKeys).to.be.equals(100);
        });

        it('should revert for zero address', async () => {
            await expect(
                providersKeys.addKeyring(ethers.constants.AddressZero, 100),
            ).to.be.revertedWith('PK:E21');
        });

        it('should revert if not called by owner', async () => {
            await expect(
                providersKeys.connect(signer).addKeyring(owner.address, 100),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('register key', function () {
        it('should register Key ', async () => {
            await providersKeys.registerKey(
                keyRingId.toString(),
                pubKey,
                expiryDate,
                generateProof(0),
            );
            await revertSnapshot(snapshot);
        });

        it('should register Key with signature', async () => {
            const {v, r, s} = await genSignatureForRegisterProviderKey(
                providersKeys,
                keyRingId.toString(),
                pubKey,
                expiryDate.toString(),
                generateProof(0),
                owner,
            );

            await providersKeys.registerKeyWithSignature(
                keyRingId.toString(),
                pubKey,
                expiryDate,
                generateProof(0),
                v,
                r,
                s,
            );
            const statistics = await providersKeys.getStatistics();
            expect(statistics.totalNumRegisteredKeys).to.be.equals(1);
            expect(statistics.totalNumAllocatedKeys).to.be.equals(100);
        });

        it('should not register key if the tree is locked', async () => {
            await providersKeys.updateTreeLock(5);
            await expect(
                providersKeys.registerKey(
                    keyRingId.toString(),
                    pubKey,
                    expiryDate,
                    generateProof(0),
                ),
            ).to.be.revertedWith('PK:E06');
            await revertSnapshot(snapshot);
        });

        it('should not register key for invalid expiry ', async () => {
            await expect(
                providersKeys.registerKey(
                    keyRingId.toString(),
                    pubKey,
                    invalidExpiry,
                    generateProof(0),
                ),
            ).to.be.revertedWith('PK:E26');
        });
    });

    describe('extendKeyExpiry', function () {
        it('should extend key expiry', async () => {
            await expect(
                providersKeys.extendKeyExpiry(
                    pubKey,
                    expiryDate,
                    newExpiryDate,
                    0,
                    generateProof(0),
                ),
            )
                .to.emit(providersKeys, 'KeyExtended')
                .withArgs(keyRingId, 0, newExpiryDate);

            await revertSnapshot(snapshot);
        });

        it('should extend key expiry with signature', async () => {
            const {v, r, s} = await genSignatureForExtendKeyRing(
                providersKeys,
                '0',
                pubKey,
                expiryDate.toString(),
                newExpiryDate.toString(),
                generateProof(0),
                owner,
            );

            await expect(
                providersKeys.extendKeyExpiryWithSignature(
                    0,
                    pubKey,
                    expiryDate,
                    newExpiryDate,
                    generateProof(0),
                    v,
                    r,
                    s,
                ),
            )
                .to.emit(providersKeys, 'KeyExtended')
                .withArgs(keyRingId, 0, newExpiryDate);

            await revertSnapshot(snapshot);
        });

        it('should revert for invalid key expiry', async () => {
            await expect(
                providersKeys.extendKeyExpiry(
                    pubKey,
                    expiryDate,
                    invalidExpiry,
                    0,
                    generateProof(0),
                ),
            ).to.be.revertedWith('PK:E26');
        });

        it('should revert if the tree is locked', async () => {
            await providersKeys.updateTreeLock(5);
            await expect(
                providersKeys.extendKeyExpiry(
                    pubKey,
                    expiryDate,
                    invalidExpiry,
                    0,
                    generateProof(0),
                ),
            ).to.be.revertedWith('PK:E06');
            await revertSnapshot(snapshot);
        });
    });

    describe('revoke key', function () {
        it('should revoke a key', async () => {
            const root1 = await providersKeys.getProvidersKeysRoot();

            const parsedOldExpiryDate: number = parseInt(
                expiryDate.toString(),
                10,
            );
            const commitment = getKeyCommitment(
                pubKey,
                BigInt(parsedOldExpiryDate),
            );

            const newCommitment = getKeyCommitment(pubKey, BigInt(0));

            const newRoot = calcNewRoot(
                root1,
                commitment,
                newCommitment,
                0,
                generateProof(0),
            );

            await expect(
                providersKeys.revokeKey(
                    keyRingId.toString(),
                    0,
                    pubKey,
                    expiryDate,
                    generateProof(0),
                ),
            )
                .to.emit(providersKeys, 'KeyRevoked')
                .withArgs(keyRingId, 0);

            const root2 = await providersKeys.getProvidersKeysRoot();

            const newRootFromContract = BigNumber.from(root2);

            expect(newRoot).equals(newRootFromContract);
            await revertSnapshot(snapshot);
        });

        it('should revoke a key with signature', async () => {
            const {v, r, s} = await genSignatureForRevokeProviderKey(
                providersKeys,
                '0',
                keyRingId.toString(),
                pubKey,
                expiryDate.toString(),
                generateProof(0),
                owner,
            );

            await expect(
                providersKeys.revokeKeyWithSignature(
                    keyRingId.toString(),
                    0,
                    pubKey,
                    expiryDate,
                    generateProof(0),
                    v,
                    r,
                    s,
                ),
            )
                .to.emit(providersKeys, 'KeyRevoked')
                .withArgs(keyRingId, 0);
        });

        it('should revert when trying to revoke the revoked key', async () => {
            await expect(
                providersKeys.revokeKey(
                    keyRingId.toString(),
                    0,
                    pubKey,
                    newExpiryDate,
                    generateProof(0),
                ),
            ).to.be.revertedWith('BIUT: Leaf is not part of the tree');
        });

        it('should revert if keyringId and KeyRingIndex do not match', async () => {
            await expect(
                providersKeys.revokeKey(
                    keyRingId.toString(),
                    1,
                    pubKey,
                    newExpiryDate,
                    generateProof(0),
                ),
            ).to.be.revertedWith('PK:E27');
        });

        it('should revert if caller address is not operator or owner', async () => {
            await expect(
                providersKeys.revokeKey(
                    keyRingId.toString(),
                    1,
                    pubKey,
                    newExpiryDate,
                    generateProof(0),
                ),
            ).to.be.revertedWith('PK:E27');
        });

        it('should revert if the tree is locked', async () => {
            await providersKeys.updateTreeLock(5);
            await expect(
                providersKeys.revokeKey(
                    keyRingId.toString(),
                    0,
                    pubKey,
                    newExpiryDate,
                    generateProof(0),
                ),
            ).to.be.revertedWith('PK:E06');
            await revertSnapshot(snapshot);
        });
    });

    describe('updateKeyringOperator', function () {
        it('should update keyring operator', async () => {
            await providersKeys.updateKeyringOperator(
                keyRingId.toString(),
                operator.address,
            );

            const keyRing = await providersKeys.keyrings(keyRingId.toString());

            expect(keyRing.operator).deep.equals(operator.address);
            await revertSnapshot(snapshot);
        });

        it('should update keyring operator with signature', async () => {
            const {v, r, s} = await genSignatureForupdateKeyRingOperator(
                providersKeys,
                keyRingId.toString(),
                operator.address,
                owner,
            );

            await providersKeys.updateKeyringOperatorWithSignature(
                keyRingId.toString(),
                operator.address,
                v,
                r,
                s,
            );

            const keyRing = await providersKeys.keyrings(keyRingId.toString());

            expect(keyRing.operator).deep.equals(operator.address);
        });

        it('should revert if unauthorized', async () => {
            await expect(
                providersKeys
                    .connect(signer)
                    .updateKeyringOperator(
                        keyRingId.toString(),
                        operator.address,
                    ),
            ).to.be.revertedWith('PK:E20');
        });

        it('should revert if new operator address is zero address', async () => {
            await expect(
                providersKeys.updateKeyringOperator(
                    keyRingId.toString(),
                    ethers.constants.AddressZero,
                ),
            ).to.be.revertedWith('PK:E21');
        });

        it('should revert if new operator address is same as existing', async () => {
            await expect(
                providersKeys
                    .connect(operator)
                    .updateKeyringOperator(
                        keyRingId.toString(),
                        operator.address,
                    ),
            ).to.be.revertedWith('PK:E22');
        });
    });

    describe('suspendKeyring', function () {
        it('should suspend a keyring', async () => {
            await expect(providersKeys.suspendKeyring(keyRingId.toString()))
                .to.emit(providersKeys, 'KeyringUpdated')
                .withArgs(keyRingId, operator.address, 2, 100);
        });

        it('should revert if the function is not called by owner', async () => {
            await expect(
                providersKeys
                    .connect(signer)
                    .suspendKeyring(keyRingId.toString()),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('reactivate keyring', function () {
        it('should reactivate a keyring', async () => {
            await expect(providersKeys.reactivateKeyring(keyRingId.toString()))
                .to.emit(providersKeys, 'KeyringUpdated')
                .withArgs(keyRingId, operator.address, 1, 100);

            const updatedkeyRing = await providersKeys.keyrings(keyRingId);
            expect(updatedkeyRing.operator).equals(operator.address);
            expect(updatedkeyRing.status).equals(1);
        });

        it('should revert when trying to reactivate active keyring', async () => {
            await expect(
                providersKeys.reactivateKeyring(keyRingId.toString()),
            ).to.be.revertedWith('PK:15');
        });

        it('should revert if the function is not called by owner', async () => {
            await expect(
                providersKeys
                    .connect(signer)
                    .reactivateKeyring(keyRingId.toString()),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('increaseKeyringKeyAllocation', function () {
        it('should increase KeyringKey Allocation ', async () => {
            const beforeupdate = await providersKeys.keyrings(keyRingId);
            expect(beforeupdate.numAllocKeys).equals(100);

            await expect(
                providersKeys.increaseKeyringKeyAllocation(
                    keyRingId.toString(),
                    100,
                ),
            )
                .to.emit(providersKeys, 'KeyringUpdated')
                .withArgs(keyRingId, operator.address, 1, 100);

            const updatedkeyRing = await providersKeys.keyrings(keyRingId);
            expect(updatedkeyRing.numAllocKeys).equals(200);
        });

        it('should revert if the function is not called by owner', async () => {
            await expect(
                providersKeys
                    .connect(signer)
                    .increaseKeyringKeyAllocation(keyRingId.toString(), 100),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });
    });

    describe('updateTreeLock', function () {
        it('should update TreeLock ', async () => {
            await expect(providersKeys.updateTreeLock(100000))
                .to.emit(providersKeys, 'TreeLockUpdated')
                .withArgs((await getBlockTimestamp()) + 100000);
        });

        it('should revert if unauthorized ', async () => {
            await expect(
                providersKeys.connect(signer).updateTreeLock(100000),
            ).to.be.revertedWith('LibDiamond: Must be contract owner');
        });

        it('should revert for max lock period', async () => {
            await expect(
                providersKeys.updateTreeLock(25920000),
            ).to.be.revertedWith('PK:E05');
        });
    });

    describe('packPubKey', function () {
        it('should return packed public key', async () => {
            const packPubKey = await providersKeys.packPubKey(pubKey);
            expect(packPubKey).to.be.equals(pubKeyPacked);
        });
    });

    describe('isAcceptablePubKey', function () {
        it('should return true if the public key is valid', async () => {
            expect(await providersKeys.isAcceptablePubKey(pubKey)).to.be.true;
        });

        it('should return false if the public key is invalid', async () => {
            const invalidPubKey = {
                x: '9487832625653172027749782479736182284968410276712116765581383594391603612850',
                y: '19341243520484112812812126668555427080517815150392255522033438580038266039458',
            };
            expect(await providersKeys.isAcceptablePubKey(invalidPubKey)).to.be
                .false;
        });
    });
});
