// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
//
// Unit tests for VaultV0Frozen.
//
// Covers:
//   - constructor argument validation
//   - constants (FIRST_NFT_ID, LAST_NFT_ID, CLAIM_WINDOW)
//   - frozen IVaultV0 surface (lockAsset / unlockAsset revert)
//   - setRoot: one-shot, only-owner, records claimOpenedAt
//   - claim:
//       * ZKP-only, NFT-only, both
//       * sequential NFT dispensation across multiple users
//       * bad proof / no root / already-claimed / empty claim / NFT exhausted
//       * Claimed event payload
//       * state updates before token transfers (claimed flag, nftsClaimed cursor)
//   - view helpers: isClaimOpen, nftsRemaining, nextNftId, verifyClaim,
//     isClaimable, sweepUnlocksAt
//   - owner sweeps: only-owner, time-locked, only after CLAIM_WINDOW elapses
//     since setRoot

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {BigNumber, BigNumberish, utils} from 'ethers';
import {ethers} from 'hardhat';

import {
    MockERC20,
    MockERC721,
    VaultV0Frozen,
} from '../../types/contracts';

const FIRST_NFT_ID = 1;
const LAST_NFT_ID = 2000;
const TOTAL_NFTS = LAST_NFT_ID - FIRST_NFT_ID + 1; // 2000
// The contract is fixed at 1-2000 (constants). Tests use a small subset of
// minted ids — they never need the full set, and "nft exhausted" reverts at
// the require() check before any transferFrom is attempted, so an unminted
// upper range is fine.
const NFTS_MINTED_PER_TEST = 15;
const ONE_YEAR = 365 * 24 * 60 * 60;
const ZERO_BYTES32 =
    '0x0000000000000000000000000000000000000000000000000000000000000000';

// --- Merkle helpers (must match VaultV0Frozen.claim leaf hashing) ---

type Entitlement = {user: string; zkpAmount: BigNumberish; nftCount: number};

const leafOf = (e: Entitlement): string => {
    const inner = utils.keccak256(
        utils.defaultAbiCoder.encode(
            ['address', 'uint256', 'uint16'],
            [e.user, e.zkpAmount, e.nftCount],
        ),
    );
    return utils.keccak256(inner);
};

const hashPair = (a: string, b: string): string => {
    const [lo, hi] = BigInt(a) < BigInt(b) ? [a, b] : [b, a];
    return utils.keccak256(utils.concat([lo, hi]));
};

const buildTree = (leaves: string[]): string[][] => {
    if (leaves.length === 0) throw new Error('no leaves');
    const levels: string[][] = [leaves.slice()];
    while (levels[levels.length - 1].length > 1) {
        const cur = levels[levels.length - 1];
        const next: string[] = [];
        for (let i = 0; i < cur.length; i += 2) {
            const a = cur[i];
            const b = i + 1 < cur.length ? cur[i + 1] : cur[i];
            next.push(hashPair(a, b));
        }
        levels.push(next);
    }
    return levels;
};

const proofOf = (levels: string[][], index: number): string[] => {
    const proof: string[] = [];
    let idx = index;
    for (let lvl = 0; lvl < levels.length - 1; lvl++) {
        const layer = levels[lvl];
        const siblingIdx = idx ^ 1;
        const sibling =
            siblingIdx < layer.length ? layer[siblingIdx] : layer[idx];
        proof.push(sibling);
        idx = Math.floor(idx / 2);
    }
    return proof;
};

// --- Helpers ---

const mintNftsToVault = async (
    nft: MockERC721,
    vault: string,
    deployer: SignerWithAddress,
    from: number,
    to: number,
): Promise<void> => {
    // MockERC721.mint uses _safeMint; the Vault implements OnERC721Received.
    for (let id = from; id <= to; ++id) {
        await nft.connect(deployer).mint(vault, id);
    }
};

const increaseTime = async (seconds: number): Promise<void> => {
    await ethers.provider.send('evm_increaseTime', [seconds]);
    await ethers.provider.send('evm_mine', []);
};

// --- Tests ---

describe('VaultV0Frozen', function () {
    let deployer: SignerWithAddress;
    let owner: SignerWithAddress;
    let other: SignerWithAddress;
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;

    let zkp: MockERC20;
    let nft: MockERC721;
    let vault: VaultV0Frozen;

    const ZERO_ADDR = ethers.constants.AddressZero;

    // Deploy once, snapshot, then revert before every test. Far cheaper
    // than re-deploying + re-minting 15 NFTs for each of ~25 tests.
    let snapshotId: string;

    before(async function () {
        [deployer, owner, other, alice, bob, carol] =
            await ethers.getSigners();

        const Erc20 = await ethers.getContractFactory('MockERC20');
        zkp = (await Erc20.deploy(1, deployer.address)) as MockERC20;

        const Erc721 = await ethers.getContractFactory('MockERC721');
        nft = (await Erc721.deploy()) as MockERC721;

        const Vault = await ethers.getContractFactory('VaultV0Frozen');
        vault = (await Vault.deploy(
            owner.address,
            zkp.address,
            nft.address,
        )) as VaultV0Frozen;

        await zkp
            .connect(deployer)
            .transfer(vault.address, ethers.utils.parseEther('1000'));
        await mintNftsToVault(
            nft,
            vault.address,
            deployer,
            FIRST_NFT_ID,
            FIRST_NFT_ID + NFTS_MINTED_PER_TEST - 1,
        );

        snapshotId = await ethers.provider.send('evm_snapshot', []);
    });

    beforeEach(async function () {
        // `evm_revert` consumes the snapshot — re-snapshot for the next test.
        await ethers.provider.send('evm_revert', [snapshotId]);
        snapshotId = await ethers.provider.send('evm_snapshot', []);
    });

    describe('deployment', () => {
        it('reverts on zero owner', async () => {
            const Vault = await ethers.getContractFactory('VaultV0Frozen');
            await expect(
                Vault.deploy(ZERO_ADDR, zkp.address, nft.address),
            ).to.be.revertedWith('ImmOwn: zero owner address');
        });

        it('reverts on zero ZKP token', async () => {
            const Vault = await ethers.getContractFactory('VaultV0Frozen');
            await expect(
                Vault.deploy(owner.address, ZERO_ADDR, nft.address),
            ).to.be.revertedWith('VFrozen: zero token');
        });

        it('reverts on zero NFT token', async () => {
            const Vault = await ethers.getContractFactory('VaultV0Frozen');
            await expect(
                Vault.deploy(owner.address, zkp.address, ZERO_ADDR),
            ).to.be.revertedWith('VFrozen: zero token');
        });

        it('exposes constants and immutables', async () => {
            expect(await vault.OWNER()).to.equal(owner.address);
            expect(await vault.ZKP_TOKEN()).to.equal(zkp.address);
            expect(await vault.NFT_TOKEN()).to.equal(nft.address);
            expect(await vault.FIRST_NFT_ID()).to.equal(FIRST_NFT_ID);
            expect(await vault.LAST_NFT_ID()).to.equal(LAST_NFT_ID);
            expect(await vault.CLAIM_WINDOW()).to.equal(ONE_YEAR);
        });

        it('starts with empty state', async () => {
            expect(await vault.root()).to.equal(ZERO_BYTES32);
            expect(await vault.nftsClaimed()).to.equal(0);
            expect(await vault.claimOpenedAt()).to.equal(0);
            expect(await vault.isClaimOpen()).to.equal(false);
            expect(await vault.sweepUnlocksAt()).to.equal(0);
            expect(await vault.nftsRemaining()).to.equal(TOTAL_NFTS);
            expect(await vault.nextNftId()).to.equal(FIRST_NFT_ID);
        });
    });

    describe('IVaultV0 surface is frozen', () => {
        const dummyLock = {
            tokenType: 0,
            token: '0x0000000000000000000000000000000000000001',
            tokenId: 0,
            extAccount: '0x0000000000000000000000000000000000000002',
            extAmount: 1,
        };

        it('lockAsset reverts for owner', async () => {
            await expect(
                vault.connect(owner).lockAsset(dummyLock),
            ).to.be.revertedWith('VFrozen: frozen');
        });

        it('lockAsset reverts for stranger', async () => {
            await expect(
                vault.connect(other).lockAsset(dummyLock),
            ).to.be.revertedWith('VFrozen: frozen');
        });

        it('unlockAsset reverts for owner', async () => {
            await expect(
                vault.connect(owner).unlockAsset(dummyLock),
            ).to.be.revertedWith('VFrozen: frozen');
        });

        it('unlockAsset reverts for stranger', async () => {
            await expect(
                vault.connect(other).unlockAsset(dummyLock),
            ).to.be.revertedWith('VFrozen: frozen');
        });
    });

    describe('setRoot', () => {
        const someRoot =
            '0x1111111111111111111111111111111111111111111111111111111111111111';

        it('reverts when called by non-owner', async () => {
            await expect(
                vault.connect(other).setRoot(someRoot),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('reverts when root is zero', async () => {
            await expect(
                vault.connect(owner).setRoot(ZERO_BYTES32),
            ).to.be.revertedWith('VFrozen: zero root');
        });

        it('sets the root, opens claims, and records the timestamp', async () => {
            const tx = await vault.connect(owner).setRoot(someRoot);
            const receipt = await tx.wait();
            const block = await ethers.provider.getBlock(receipt.blockNumber);

            expect(await vault.root()).to.equal(someRoot);
            expect(await vault.claimOpenedAt()).to.equal(block.timestamp);
            expect(await vault.isClaimOpen()).to.equal(true);
            expect(await vault.sweepUnlocksAt()).to.equal(
                block.timestamp + ONE_YEAR,
            );
        });

        it('emits RootSet', async () => {
            await expect(vault.connect(owner).setRoot(someRoot))
                .to.emit(vault, 'RootSet')
                .withArgs(someRoot);
        });

        it('cannot be set twice', async () => {
            await vault.connect(owner).setRoot(someRoot);
            await expect(
                vault.connect(owner).setRoot(someRoot),
            ).to.be.revertedWith('VFrozen: root set');
        });
    });

    describe('claim', () => {
        // Build a small tree with three users.
        let entitlements: Entitlement[];
        let levels: string[][];

        const open = async (): Promise<void> => {
            entitlements = [
                {
                    user: alice.address.toLowerCase(),
                    zkpAmount: ethers.utils.parseEther('100'),
                    nftCount: 3,
                },
                {
                    user: bob.address.toLowerCase(),
                    zkpAmount: ethers.utils.parseEther('50'),
                    nftCount: 0,
                },
                {
                    user: carol.address.toLowerCase(),
                    zkpAmount: 0,
                    nftCount: 2,
                },
            ];
            const leaves = entitlements.map(leafOf);
            levels = buildTree(leaves);
            await vault.connect(owner).setRoot(levels[levels.length - 1][0]);
        };

        it('reverts when root has not been set', async () => {
            await expect(
                vault.connect(alice).claim(1, 0, true, []),
            ).to.be.revertedWith('VFrozen: not open');
        });

        it('reverts on empty claim', async () => {
            await open();
            await expect(
                vault.connect(alice).claim(0, 0, true, []),
            ).to.be.revertedWith('VFrozen: empty claim');
        });

        it('reverts on bad proof (wrong user)', async () => {
            await open();
            const aliceProof = proofOf(levels, 0);
            // Bob submits Alice's amount with Alice's proof — leaf computes
            // against bob.address and won't match.
            await expect(
                vault
                    .connect(bob)
                    .claim(
                        entitlements[0].zkpAmount,
                        entitlements[0].nftCount, true,
                        aliceProof,
                    ),
            ).to.be.revertedWith('VFrozen: bad proof');
        });

        it('reverts on bad proof (wrong amount)', async () => {
            await open();
            const aliceProof = proofOf(levels, 0);
            await expect(
                vault
                    .connect(alice)
                    .claim(
                        ethers.utils.parseEther('999'),
                        entitlements[0].nftCount, true,
                        aliceProof,
                    ),
            ).to.be.revertedWith('VFrozen: bad proof');
        });

        it('reverts on bad proof (wrong nftCount)', async () => {
            await open();
            const aliceProof = proofOf(levels, 0);
            await expect(
                vault
                    .connect(alice)
                    .claim(entitlements[0].zkpAmount, 99, true, aliceProof),
            ).to.be.revertedWith('VFrozen: bad proof');
        });

        it('reverts on empty proof when there are multiple leaves', async () => {
            await open();
            await expect(
                vault
                    .connect(alice)
                    .claim(
                        entitlements[0].zkpAmount,
                        entitlements[0].nftCount, true,
                        [],
                    ),
            ).to.be.revertedWith('VFrozen: bad proof');
        });

        it('pays ZKP and dispenses NFTs in sequence for Alice', async () => {
            await open();
            const proof = proofOf(levels, 0);

            const zkpBefore = await zkp.balanceOf(alice.address);
            const nftBefore = await nft.balanceOf(alice.address);

            await expect(
                vault
                    .connect(alice)
                    .claim(
                        entitlements[0].zkpAmount,
                        entitlements[0].nftCount, true,
                        proof,
                    ),
            )
                .to.emit(vault, 'Claimed')
                .withArgs(
                    alice.address,
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount,
                    FIRST_NFT_ID,
                );

            expect(
                (await zkp.balanceOf(alice.address)).sub(zkpBefore),
            ).to.equal(entitlements[0].zkpAmount);
            expect(
                (await nft.balanceOf(alice.address)).sub(nftBefore),
            ).to.equal(entitlements[0].nftCount);
            // Alice receives ids 1, 2, 3
            expect(await nft.ownerOf(1)).to.equal(alice.address);
            expect(await nft.ownerOf(2)).to.equal(alice.address);
            expect(await nft.ownerOf(3)).to.equal(alice.address);

            expect(await vault.claimed(alice.address)).to.equal(true);
            expect(await vault.nftsClaimed()).to.equal(3);
            expect(await vault.nextNftId()).to.equal(4);
            expect(await vault.nftsRemaining()).to.equal(TOTAL_NFTS - 3);
        });

        it('handles ZKP-only claim (Bob, nftCount=0)', async () => {
            await open();
            const proof = proofOf(levels, 1);

            const cursorBefore = await vault.nftsClaimed();
            const nftBefore = await nft.balanceOf(bob.address);

            await expect(
                vault
                    .connect(bob)
                    .claim(
                        entitlements[1].zkpAmount,
                        entitlements[1].nftCount, true,
                        proof,
                    ),
            ).to.emit(vault, 'Claimed');

            expect(await zkp.balanceOf(bob.address)).to.equal(
                entitlements[1].zkpAmount,
            );
            expect(await nft.balanceOf(bob.address)).to.equal(nftBefore);
            expect(await vault.nftsClaimed()).to.equal(cursorBefore); // unchanged
        });

        it('handles NFT-only claim (Carol, zkpAmount=0)', async () => {
            await open();
            const proof = proofOf(levels, 2);

            await vault
                .connect(carol)
                .claim(
                    entitlements[2].zkpAmount,
                    entitlements[2].nftCount, true,
                    proof,
                );

            expect(await zkp.balanceOf(carol.address)).to.equal(0);
            expect(await nft.balanceOf(carol.address)).to.equal(2);
            expect(await vault.nftsClaimed()).to.equal(2);
        });

        it('sequential claims advance the NFT cursor correctly', async () => {
            await open();
            await vault
                .connect(alice)
                .claim(
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount, true,
                    proofOf(levels, 0),
                );
            // cursor at 4
            await vault
                .connect(carol)
                .claim(
                    entitlements[2].zkpAmount,
                    entitlements[2].nftCount, true,
                    proofOf(levels, 2),
                );
            // Carol got ids 4, 5
            expect(await nft.ownerOf(4)).to.equal(carol.address);
            expect(await nft.ownerOf(5)).to.equal(carol.address);
            expect(await vault.nftsClaimed()).to.equal(5);
            expect(await vault.nextNftId()).to.equal(6);
        });

        it('reverts on double-claim by the same user', async () => {
            await open();
            const proof = proofOf(levels, 0);
            await vault
                .connect(alice)
                .claim(
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount, true,
                    proof,
                );
            await expect(
                vault
                    .connect(alice)
                    .claim(
                        entitlements[0].zkpAmount,
                        entitlements[0].nftCount, true,
                        proof,
                    ),
            ).to.be.revertedWith('VFrozen: claimed');
        });

        it('reverts when nftCount > remaining capacity', async () => {
            // Single-leaf tree: a user entitled to all 2001 NFTs (one more
            // than the Vault holds). claim should revert at the cursor check.
            const big: Entitlement[] = [
                {
                    user: alice.address.toLowerCase(),
                    zkpAmount: 0,
                    nftCount: TOTAL_NFTS + 1, // 2001
                },
            ];
            const lvls = buildTree(big.map(leafOf));
            await vault.connect(owner).setRoot(lvls[lvls.length - 1][0]);

            await expect(
                vault
                    .connect(alice)
                    .claim(0, TOTAL_NFTS + 1, true, proofOf(lvls, 0)),
            ).to.be.revertedWith('VFrozen: nft exhausted');
        });

        it('isClaimable() combined check matches actual claim behavior', async () => {
            await open();
            const proof = proofOf(levels, 0);

            expect(
                await vault.isClaimable(
                    alice.address,
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount, true,
                    proof,
                ),
            ).to.equal(true);

            // Wrong amount
            expect(
                await vault.isClaimable(
                    alice.address,
                    ethers.utils.parseEther('1'),
                    entitlements[0].nftCount, true,
                    proof,
                ),
            ).to.equal(false);

            // After claiming
            await vault
                .connect(alice)
                .claim(
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount, true,
                    proof,
                );
            expect(
                await vault.isClaimable(
                    alice.address,
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount, true,
                    proof,
                ),
            ).to.equal(false);
        });

        it('verifyClaim() validates the proof regardless of claimed flag', async () => {
            await open();
            const proof = proofOf(levels, 0);
            expect(
                await vault.verifyClaim(
                    alice.address,
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount,
                    proof,
                ),
            ).to.equal(true);

            // Even after claiming, the proof itself is still valid.
            await vault
                .connect(alice)
                .claim(
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount, true,
                    proof,
                );
            expect(
                await vault.verifyClaim(
                    alice.address,
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount,
                    proof,
                ),
            ).to.equal(true);
        });

        it('verifyClaim() returns false when root is not set', async () => {
            // No open() — root is still zero.
            expect(
                await vault.verifyClaim(alice.address, 0, 0, []),
            ).to.equal(false);
        });

        it('single-leaf tree: empty proof verifies', async () => {
            const single: Entitlement[] = [
                {
                    user: alice.address.toLowerCase(),
                    zkpAmount: ethers.utils.parseEther('7'),
                    nftCount: 1,
                },
            ];
            const lvls = buildTree(single.map(leafOf));
            await vault.connect(owner).setRoot(lvls[lvls.length - 1][0]);
            // Single leaf == root, so the proof array is empty.
            await vault
                .connect(alice)
                .claim(single[0].zkpAmount, single[0].nftCount, true, []);
            expect(await zkp.balanceOf(alice.address)).to.equal(
                single[0].zkpAmount,
            );
            expect(await nft.ownerOf(1)).to.equal(alice.address);
        });

        describe('claimNft = false (skip NFTs)', () => {
            it('pays ZKP, does not dispense NFTs, does not advance cursor', async () => {
                await open();
                const proof = proofOf(levels, 0);

                const nftBefore = await nft.balanceOf(alice.address);
                const cursorBefore = await vault.nftsClaimed();

                await expect(
                    vault
                        .connect(alice)
                        .claim(
                            entitlements[0].zkpAmount,
                            entitlements[0].nftCount,
                            false, // claimNft
                            proof,
                        ),
                )
                    .to.emit(vault, 'Claimed')
                    .withArgs(
                        alice.address,
                        entitlements[0].zkpAmount,
                        0, // 0 NFTs actually dispensed
                        FIRST_NFT_ID,
                    );

                expect(await zkp.balanceOf(alice.address)).to.equal(
                    entitlements[0].zkpAmount,
                );
                expect(await nft.balanceOf(alice.address)).to.equal(nftBefore);
                expect(await vault.nftsClaimed()).to.equal(cursorBefore);
                expect(await vault.claimed(alice.address)).to.equal(true);
            });

            it('claimNft=false then another user claims NFTs: cursor still starts at FIRST_NFT_ID', async () => {
                await open();

                await vault
                    .connect(alice)
                    .claim(
                        entitlements[0].zkpAmount,
                        entitlements[0].nftCount,
                        false,
                        proofOf(levels, 0),
                    );
                // Cursor must still be 0; Carol must receive ids 1, 2.
                expect(await vault.nextNftId()).to.equal(FIRST_NFT_ID);
                await vault
                    .connect(carol)
                    .claim(
                        entitlements[2].zkpAmount,
                        entitlements[2].nftCount,
                        true,
                        proofOf(levels, 2),
                    );
                expect(await nft.ownerOf(1)).to.equal(carol.address);
                expect(await nft.ownerOf(2)).to.equal(carol.address);
                expect(await vault.nftsClaimed()).to.equal(2);
            });

            it('reverts on empty claim when zkpAmount=0 and claimNft=false', async () => {
                await open();
                const proof = proofOf(levels, 2); // carol: zkp=0, nft=2
                await expect(
                    vault
                        .connect(carol)
                        .claim(
                            entitlements[2].zkpAmount, // 0
                            entitlements[2].nftCount, // 2
                            false, // skip NFTs => effectively empty
                            proof,
                        ),
                ).to.be.revertedWith('VFrozen: empty claim');
            });

            it('claimNft=false sets the claimed flag; user cannot retry with claimNft=true', async () => {
                await open();
                const proof = proofOf(levels, 0);
                await vault
                    .connect(alice)
                    .claim(
                        entitlements[0].zkpAmount,
                        entitlements[0].nftCount,
                        false,
                        proof,
                    );
                await expect(
                    vault
                        .connect(alice)
                        .claim(
                            entitlements[0].zkpAmount,
                            entitlements[0].nftCount,
                            true,
                            proof,
                        ),
                ).to.be.revertedWith('VFrozen: claimed');
            });

            it('isClaimable() respects claimNft flag', async () => {
                await open();
                const proof = proofOf(levels, 2); // carol: zkp=0, nft=2

                // With claimNft=true: would succeed.
                expect(
                    await vault.isClaimable(
                        carol.address,
                        entitlements[2].zkpAmount,
                        entitlements[2].nftCount,
                        true,
                        proof,
                    ),
                ).to.equal(true);

                // With claimNft=false and zkpAmount=0: empty, so false.
                expect(
                    await vault.isClaimable(
                        carol.address,
                        entitlements[2].zkpAmount,
                        entitlements[2].nftCount,
                        false,
                        proof,
                    ),
                ).to.equal(false);
            });
        });
    });

    describe('owner sweep (time-locked 1 year)', () => {
        const someRoot =
            '0x1111111111111111111111111111111111111111111111111111111111111111';

        it('sweepUnlocksAt returns 0 before setRoot, claimOpenedAt+1y after', async () => {
            expect(await vault.sweepUnlocksAt()).to.equal(0);
            await vault.connect(owner).setRoot(someRoot);
            const openedAt = await vault.claimOpenedAt();
            expect(await vault.sweepUnlocksAt()).to.equal(
                openedAt.add(ONE_YEAR),
            );
        });

        it('ownerSweepErc20 reverts before claims open', async () => {
            await expect(
                vault
                    .connect(owner)
                    .ownerSweepErc20(zkp.address, owner.address, 1),
            ).to.be.revertedWith('VFrozen: claims not open');
        });

        it('ownerSweepNft reverts before claims open', async () => {
            await expect(
                vault
                    .connect(owner)
                    .ownerSweepNft(owner.address, [FIRST_NFT_ID]),
            ).to.be.revertedWith('VFrozen: claims not open');
        });

        it('ownerSweepErc20 reverts inside the 1-year window', async () => {
            await vault.connect(owner).setRoot(someRoot);
            await increaseTime(ONE_YEAR - 60); // 1 minute short
            await expect(
                vault
                    .connect(owner)
                    .ownerSweepErc20(zkp.address, owner.address, 1),
            ).to.be.revertedWith('VFrozen: too early');
        });

        it('ownerSweepErc20 succeeds after 1 year and emits OwnerSwept', async () => {
            await vault.connect(owner).setRoot(someRoot);
            await increaseTime(ONE_YEAR);

            const amount = ethers.utils.parseEther('123');
            await expect(
                vault
                    .connect(owner)
                    .ownerSweepErc20(zkp.address, owner.address, amount),
            )
                .to.emit(vault, 'OwnerSwept')
                .withArgs(zkp.address, owner.address, amount);
            expect(await zkp.balanceOf(owner.address)).to.equal(amount);
        });

        it('ownerSweepNft succeeds after 1 year', async () => {
            await vault.connect(owner).setRoot(someRoot);
            await increaseTime(ONE_YEAR);

            const ids = [10, 11, 12];
            await vault
                .connect(owner)
                .ownerSweepNft(owner.address, ids);
            for (const id of ids) {
                expect(await nft.ownerOf(id)).to.equal(owner.address);
            }
        });

        it('ownerSweepErc20 rejects non-owner even after 1 year', async () => {
            await vault.connect(owner).setRoot(someRoot);
            await increaseTime(ONE_YEAR);
            await expect(
                vault
                    .connect(other)
                    .ownerSweepErc20(zkp.address, other.address, 1),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('ownerSweepNft rejects non-owner even after 1 year', async () => {
            await vault.connect(owner).setRoot(someRoot);
            await increaseTime(ONE_YEAR);
            await expect(
                vault
                    .connect(other)
                    .ownerSweepNft(other.address, [FIRST_NFT_ID]),
            ).to.be.revertedWith('ImmOwn: unauthorized');
        });

        it('ownerSweepErc20 rejects zero recipient', async () => {
            await vault.connect(owner).setRoot(someRoot);
            await increaseTime(ONE_YEAR);
            await expect(
                vault
                    .connect(owner)
                    .ownerSweepErc20(zkp.address, ZERO_ADDR, 1),
            ).to.be.revertedWith('VFrozen: zero to');
        });

        it('ownerSweepNft rejects zero recipient', async () => {
            await vault.connect(owner).setRoot(someRoot);
            await increaseTime(ONE_YEAR);
            await expect(
                vault
                    .connect(owner)
                    .ownerSweepNft(ZERO_ADDR, [FIRST_NFT_ID]),
            ).to.be.revertedWith('VFrozen: zero to');
        });
    });

    describe('end-to-end: 3 users claim within window, sweep after', () => {
        it('claim phase then sweep phase', async () => {
            const entitlements: Entitlement[] = [
                {
                    user: alice.address.toLowerCase(),
                    zkpAmount: ethers.utils.parseEther('100'),
                    nftCount: 5,
                },
                {
                    user: bob.address.toLowerCase(),
                    zkpAmount: ethers.utils.parseEther('200'),
                    nftCount: 0,
                },
                {
                    user: carol.address.toLowerCase(),
                    zkpAmount: 0,
                    nftCount: 3,
                },
            ];
            const lvls = buildTree(entitlements.map(leafOf));
            await vault.connect(owner).setRoot(lvls[lvls.length - 1][0]);

            await vault
                .connect(alice)
                .claim(
                    entitlements[0].zkpAmount,
                    entitlements[0].nftCount, true,
                    proofOf(lvls, 0),
                );
            await vault
                .connect(bob)
                .claim(
                    entitlements[1].zkpAmount,
                    entitlements[1].nftCount, true,
                    proofOf(lvls, 1),
                );
            await vault
                .connect(carol)
                .claim(
                    entitlements[2].zkpAmount,
                    entitlements[2].nftCount, true,
                    proofOf(lvls, 2),
                );

            // Alice ids 1..5, Carol ids 6..8 (Bob got none)
            for (let id = 1; id <= 5; ++id)
                expect(await nft.ownerOf(id)).to.equal(alice.address);
            for (let id = 6; id <= 8; ++id)
                expect(await nft.ownerOf(id)).to.equal(carol.address);
            expect(await vault.nftsClaimed()).to.equal(8);

            // Sweep blocked before the window ends.
            await expect(
                vault
                    .connect(owner)
                    .ownerSweepErc20(zkp.address, owner.address, 1),
            ).to.be.revertedWith('VFrozen: too early');

            await increaseTime(ONE_YEAR);

            // Owner sweeps the remaining ZKP and a couple of unclaimed NFTs.
            const remainingZkp = await zkp.balanceOf(vault.address);
            await vault
                .connect(owner)
                .ownerSweepErc20(
                    zkp.address,
                    owner.address,
                    remainingZkp,
                );
            await vault.connect(owner).ownerSweepNft(owner.address, [9, 10]);
            expect(await zkp.balanceOf(vault.address)).to.equal(0);
            expect(await nft.ownerOf(9)).to.equal(owner.address);
            expect(await nft.ownerOf(10)).to.equal(owner.address);
        });
    });
});
