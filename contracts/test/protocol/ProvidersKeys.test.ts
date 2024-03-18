// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {BigNumberish} from '@ethersproject/bignumber/src.ts';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {poseidon2or3} from '@panther-core/crypto/lib/base/hashes';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {MerkleTree} from '@zk-kit/merkle-tree';
import {expect} from 'chai';
import {poseidon} from 'circomlibjs';
import {BigNumber} from 'ethers';
import hre, {ethers} from 'hardhat';

import {genSignatureForRegisterProviderKey} from '../../lib/eip712SignatureGenerator';
import {ProvidersKeys, PantherStaticTree} from '../../types/contracts';
import type {G1PointStruct} from '../../types/contracts/ProvidersKeys';

import {
    getPoseidonT3Contract,
    getPoseidonT4Contract,
} from './../../lib/poseidonBuilder';
import {
    revertSnapshot,
    takeSnapshot,
    getBlockTimestamp,
} from './helpers/hardhat';

function getKeyCommitment(
    key: G1PointStruct,
    expiryDate: bigint,
): BigNumberish {
    const commitment = poseidon2or3([key.x, key.y, expiryDate]);
    return commitment;
}

function generateleaf(): BigNumberish {
    const leaf = ethers.BigNumber.from(
        ethers.utils.formatBytes32String('random-leaf'),
    ).mod(SNARK_FIELD_SIZE)._hex;
    return leaf;
}

function generateProof(leafIndex: number): Bytes[] {
    const zeroValue =
        '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d';
    const merkleTree = new MerkleTree(poseidon, 16, zeroValue);
    const leaf = generateleaf();
    merkleTree.insert(leaf);

    const proof = merkleTree.createProof(leafIndex);

    return proof.siblingNodes.map(x => ethers.BigNumber.from(x)._hex);
}

function calcNewRoot(
    curRoot: BigNumberish,
    leaf: BigNumberish,
    newLeaf: BigNumberish,
    leafIndex: number,
    proofSiblings: BigNumberish[],
): BigNumberish {
    if (newLeaf === leaf) {
        throw new Error('BIUT: New leaf cannot be equal to the old one');
    }

    let _newRoot: any = newLeaf;
    let proofPathIndice: number;

    for (let i = 0; i < proofSiblings.length; i++) {
        proofPathIndice = (leafIndex >> i) & 1;

        if (proofPathIndice === 0) {
            _newRoot = poseidon2or3([_newRoot, proofSiblings[i]]);
        } else {
            _newRoot = poseidon2or3([proofSiblings[i], _newRoot]);
        }
    }

    return _newRoot;
}

describe('ProvidersKeys contract', function () {
    this.timeout('100000000000');
    let providersKeys: ProvidersKeys;
    let pantherStaticTree: FakeContract<PantherStaticTree>;
    let owner: SignerWithAddress;
    let signer: SignerWithAddress;
    let operator: SignerWithAddress;
    let expiryDate: string;
    let newExpiryDate: string;
    let invalidExpiry: string;
    let pubKey: G1PointStruct;
    let pubKeyPacked: any;
    let keyRingId: number;
    let snapshot: number;

    before(async () => {
        pubKey = {
            x: '9487832625653172027749782479736182284968410276712116765581383594391603612850',
            y: '20341243520484112812812126668555427080517815150392255522033438580038266039458',
        };
        pubKeyPacked =
            '0x2cf8bc5fc9c122f6cc883988fd57e45ad086ec2785d2dfbfa85032373f90aca2';
        expiryDate = '1735689600';
        newExpiryDate = '1935689800';
        invalidExpiry = '1708006666';

        [owner, signer, operator] = await ethers.getSigners();

        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        const PoseidonT4 = await getPoseidonT4Contract();
        const poseidonT4 = await PoseidonT4.deploy();
        await poseidonT4.deployed();

        pantherStaticTree = await smock.fake('PantherStaticTree', {});

        const ProvidersKeys = await ethers.getContractFactory('ProvidersKeys', {
            libraries: {
                PoseidonT3: poseidonT3.address,
                PoseidonT4: poseidonT4.address,
            },
        });
        providersKeys = (await ProvidersKeys.deploy(
            owner.address,
            1,
            pantherStaticTree.address,
        )) as ProvidersKeys;
    });

    beforeEach(async () => {
        snapshot = await takeSnapshot();
    });

    describe('deployment', function () {
        it('should set the correct pantherStaticTree address', async function () {
            expect(await providersKeys.PANTHER_STATIC_TREE()).to.equal(
                pantherStaticTree.address,
            );
        });

        it('should revert if pantherStaticTree address is not valid', async function () {
            const PoseidonT3 = await getPoseidonT3Contract();
            const poseidonT3 = await PoseidonT3.deploy();
            await poseidonT3.deployed();

            const PoseidonT4 = await getPoseidonT4Contract();
            const poseidonT4 = await PoseidonT4.deploy();
            await poseidonT4.deployed();

            const ProvidersKeys = await ethers.getContractFactory(
                'ProvidersKeys',
                {
                    libraries: {
                        PoseidonT3: poseidonT3.address,
                        PoseidonT4: poseidonT4.address,
                    },
                },
            );

            await expect(
                ProvidersKeys.deploy(
                    owner.address,
                    1,
                    ethers.constants.AddressZero,
                ),
            ).to.be.revertedWith('PK:init');
        });
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
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });
    });

    describe('register key with signature', function () {
        it('should register Key', async () => {
            const {v, r, s} = await genSignatureForRegisterProviderKey(
                hre,
                providersKeys,
                keyRingId.toString(),
                pubKey,
                expiryDate,
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
            await revertSnapshot(snapshot);
        });

        it('should not register key if the tree is locked', async () => {
            await providersKeys.updateTreeLock(5);

            const {v, r, s} = await genSignatureForRegisterProviderKey(
                hre,
                providersKeys,
                keyRingId.toString(),
                pubKey,
                expiryDate,
                generateProof(0),
                owner,
            );
            await expect(
                providersKeys.registerKeyWithSignature(
                    keyRingId.toString(),
                    pubKey,
                    expiryDate,
                    generateProof(0),
                    v,
                    r,
                    s,
                ),
            ).to.be.revertedWith('PK:E06');
            await revertSnapshot(snapshot);
        });

        it('should not register key for invalid expiry ', async () => {
            const {v, r, s} = await genSignatureForRegisterProviderKey(
                hre,
                providersKeys,
                keyRingId.toString(),
                pubKey,
                expiryDate,
                generateProof(0),
                owner,
            );
            await expect(
                providersKeys.registerKeyWithSignature(
                    keyRingId.toString(),
                    pubKey,
                    invalidExpiry,
                    generateProof(0),
                    v,
                    r,
                    s,
                ),
            ).to.be.revertedWith('PK:E26');
        });
    });

    describe('register key without signature', function () {
        it('should register Key for valid inputs', async () => {
            await providersKeys.registerKey(
                keyRingId.toString(),
                pubKey,
                expiryDate,
                generateProof(0),
            );
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
            await providersKeys.extendKeyExpiry(
                pubKey,
                expiryDate,
                newExpiryDate,
                0,
                generateProof(0),
            );
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
            const root1 = await providersKeys.getRoot();

            const parsedOldExpiryDate: number = parseInt(
                expiryDate.toString(),
                10,
            );
            const commitment = getKeyCommitment(pubKey, parsedOldExpiryDate);

            const newCommitment = getKeyCommitment(pubKey, 0);

            const newRoot = calcNewRoot(
                root1,
                commitment,
                newCommitment,
                0,
                generateProof(0),
            );

            await providersKeys.revokeKey(
                keyRingId.toString(),
                0,
                pubKey,
                newExpiryDate,
                generateProof(0),
            );

            const root2 = await providersKeys.getRoot();

            const newRootFromContract = BigNumber.from(root2);

            expect(newRoot).equals(newRootFromContract);
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

        it('should revert if keyringId operator and caller address do not match', async () => {
            await expect(
                providersKeys
                    .connect(operator)
                    .revokeKey(
                        keyRingId.toString(),
                        0,
                        pubKey,
                        newExpiryDate,
                        generateProof(0),
                    ),
            ).to.be.revertedWith('PK:E20');
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
            ).to.be.revertedWith('ImmOwn: unauthorized');
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
            ).to.be.revertedWith('ImmOwn: unauthorized');
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
});
