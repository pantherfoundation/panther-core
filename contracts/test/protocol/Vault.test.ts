// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import crypto from 'crypto';

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {SaltedLockDataStruct} from '@panther-core/dapp/src/types/contracts/Vault';
import chai, {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {TokenType} from '../../lib/token';
import {toBigNum} from '../../lib/utilities';
import {VaultV1, IERC20, IERC721, IERC1155} from '../../types/contracts';

import {ADDRESS_ZERO, composeERC20SenderStealthAddress} from './shared';

chai.use(smock.matchers);

describe('VaultV1 contract', function () {
    let vault: VaultV1;
    let erc20Token: FakeContract<IERC20>;
    let erc721Token: FakeContract<IERC721>;
    let erc1155Token: FakeContract<IERC1155>;
    let owner: SignerWithAddress;
    let extAccount: SignerWithAddress;
    let lockData: LockData;
    let saltedLockData: SaltedLockDataStruct;

    const oneEth = ethers.constants.WeiPerEther;

    before(async function () {
        [owner, extAccount] = await ethers.getSigners();

        const Vault = await ethers.getContractFactory('VaultV1');
        vault = (await Vault.deploy(owner.address)) as VaultV1;

        erc20Token = await smock.fake('IERC20');
        erc721Token = await smock.fake('IERC721');
        erc1155Token = await smock.fake('IERC1155');
    });

    describe('function lockAsset', () => {
        describe('Erc20', () => {
            before(() => {
                erc20Token.transferFrom.returns(true);
                erc20Token.transfer.returns(true);

                lockData = genLockData(TokenType.Erc20, erc20Token.address);
            });

            it('should lock erc20', async () => {
                await expect(vault.lockAsset(lockData))
                    .to.emit(vault, 'Locked')
                    .withArgs([
                        lockData.tokenType,
                        lockData.token,
                        lockData.tokenId,
                        lockData.extAccount,
                        lockData.extAmount,
                    ]);

                expect(erc20Token.transferFrom).to.have.been.calledWith(
                    extAccount.address,
                    vault.address,
                    lockData.extAmount,
                );
            });
        });

        describe('Erc721', () => {
            before(() => {
                erc721Token[
                    'safeTransferFrom(address,address,uint256)'
                ].returns(true);

                lockData = genLockData(TokenType.Erc721, erc721Token.address);
            });

            it('should lock erc721', async () => {
                await expect(vault.lockAsset(lockData))
                    .to.emit(vault, 'Locked')
                    .withArgs([
                        lockData.tokenType,
                        lockData.token,
                        lockData.tokenId,
                        lockData.extAccount,
                        lockData.extAmount,
                    ]);

                expect(
                    erc721Token['safeTransferFrom(address,address,uint256)'],
                ).to.have.been.calledWith(
                    extAccount.address,
                    vault.address,
                    lockData.tokenId,
                );
            });
        });

        describe('Erc1155', () => {
            before(() => {
                erc1155Token.safeTransferFrom.returns(true);

                lockData = genLockData(TokenType.Erc1155, erc1155Token.address);
            });

            it('should lock erc1155', async () => {
                await expect(vault.lockAsset(lockData))
                    .to.emit(vault, 'Locked')
                    .withArgs([
                        lockData.tokenType,
                        lockData.token,
                        lockData.tokenId,
                        lockData.extAccount,
                        lockData.extAmount,
                    ]);

                expect(erc1155Token.safeTransferFrom).to.have.been.calledWith(
                    extAccount.address,
                    vault.address,
                    lockData.tokenId,
                    lockData.extAmount,
                    '0x',
                );
            });
        });
    });

    describe('function unlockAsset', () => {
        describe('Erc20', () => {
            before(() => {
                erc20Token.transferFrom.returns(true);
                erc20Token.transfer.returns(true);

                lockData = genLockData(TokenType.Erc20, erc20Token.address);
            });

            it('should unlock erc20', async () => {
                await expect(vault.unlockAsset(lockData))
                    .to.emit(vault, 'Unlocked')
                    .withArgs([
                        lockData.tokenType,
                        lockData.token,
                        lockData.tokenId,
                        lockData.extAccount,
                        lockData.extAmount,
                    ]);

                expect(erc20Token.transfer).to.have.been.calledWith(
                    extAccount.address,
                    lockData.extAmount,
                );
            });
        });

        describe('Erc721', () => {
            before(() => {
                erc721Token[
                    'safeTransferFrom(address,address,uint256)'
                ].returns(true);

                lockData = genLockData(TokenType.Erc721, erc721Token.address);
            });

            it('should unlock erc721', async () => {
                await expect(vault.unlockAsset(lockData))
                    .to.emit(vault, 'Unlocked')
                    .withArgs([
                        lockData.tokenType,
                        lockData.token,
                        lockData.tokenId,
                        lockData.extAccount,
                        lockData.extAmount,
                    ]);

                expect(
                    erc721Token['safeTransferFrom(address,address,uint256)'],
                ).to.have.been.calledWith(
                    vault.address,
                    extAccount.address,
                    lockData.tokenId,
                );
            });
        });

        describe('Erc1155', () => {
            before(() => {
                erc1155Token.safeTransferFrom.returns(true);

                lockData = genLockData(TokenType.Erc1155, erc1155Token.address);
            });

            it('should unlock erc1155', async () => {
                await expect(vault.unlockAsset(lockData))
                    .to.emit(vault, 'Unlocked')
                    .withArgs([
                        lockData.tokenType,
                        lockData.token,
                        lockData.tokenId,
                        lockData.extAccount,
                        lockData.extAmount,
                    ]);

                expect(erc1155Token.safeTransferFrom).to.have.been.calledWith(
                    vault.address,
                    extAccount.address,
                    lockData.tokenId,
                    lockData.extAmount,
                    '0x',
                );
            });
        });

        describe('Native token', () => {
            before(async () => {
                saltedLockData = extendLockDataWithSalt(
                    genLockData(TokenType.Native, ethers.constants.AddressZero),
                );
                saltedLockData.extAmount = oneEth;

                // Let add ETH to the vault's balance
                saltedLockData.extAccount = owner.address;
                await vault.lockAssetWithSalt(saltedLockData, {value: oneEth});
                expect(
                    await ethers.provider.getBalance(vault.address),
                ).to.be.equal(oneEth);

                // Now ready to unlock to the external account
                saltedLockData.extAccount = extAccount.address;
            });

            it('should unlock native token', async () => {
                const balanceVaultBefore = await ethers.provider.getBalance(
                    vault.address,
                );
                const balanceToBefore = await ethers.provider.getBalance(
                    saltedLockData.extAccount,
                );

                await vault.unlockAsset(saltedLockData);

                const balanceVaultAfter = await ethers.provider.getBalance(
                    vault.address,
                );
                const balanceToAfter = await ethers.provider.getBalance(
                    saltedLockData.extAccount,
                );
                expect(balanceVaultBefore.sub(balanceVaultAfter)).to.be.equal(
                    oneEth,
                );
                expect(balanceToAfter.sub(balanceToBefore)).to.be.equal(oneEth);
            });
        });
    });

    describe('function lockAssetWithSalt', () => {
        let saltedLockData: SaltedLockDataStruct;
        let token;
        let stealthAddress;
        let deployerAddress;
        let tokenType;
        const salt =
            '0x00fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fe';
        const amount = 1e2;

        before(async () => {
            deployerAddress = owner.address;
            const MockERC20 = await ethers.getContractFactory('MockERC20');
            token = await MockERC20.deploy(0, deployerAddress);
        });

        describe('Erc20', () => {
            before(async () => {
                tokenType = TokenType.Erc20;
                saltedLockData = {
                    tokenType: tokenType,
                    token: token.address,
                    tokenId: 0,
                    salt: salt,
                    extAccount: owner.address,
                    extAmount: amount,
                };
                expect(await token.balanceOf(deployerAddress)).gt(
                    saltedLockData.extAmount,
                );

                stealthAddress = composeERC20SenderStealthAddress(
                    saltedLockData,
                    vault.address,
                );

                await token.transfer(extAccount.address, amount);

                await token
                    .connect(owner)
                    .approve(stealthAddress, saltedLockData.extAmount);

                const allowance = await token.allowance(
                    deployerAddress,
                    stealthAddress,
                );

                await expect(allowance).gte(saltedLockData.extAmount);
            });

            it('should lock erc20', async () => {
                await expect(await vault.lockAssetWithSalt(saltedLockData))
                    .to.emit(vault, 'Locked')
                    .withArgs([
                        saltedLockData.tokenType,
                        saltedLockData.token,
                        saltedLockData.tokenId,
                        saltedLockData.extAccount,
                        saltedLockData.extAmount,
                    ]);
            });
        });

        describe('Erc721', () => {
            before(async () => {
                const tokenId = 333;
                token = await (
                    await ethers.getContractFactory('MockERC721')
                ).deploy();
                await token.mint(extAccount.address, tokenId);
                tokenType = TokenType.Erc721;
                saltedLockData = {
                    tokenType: tokenType,
                    token: token.address,
                    tokenId: tokenId,
                    salt: salt,
                    extAccount: extAccount.address,
                    extAmount: 1,
                };

                expect(await token.ownerOf(tokenId)).eq(extAccount.address);

                stealthAddress = composeERC20SenderStealthAddress(
                    saltedLockData,
                    vault.address,
                );

                await token
                    .connect(extAccount)
                    .approve(stealthAddress, tokenId);

                const approved = await token.getApproved(tokenId);

                await expect(approved).eq(stealthAddress);
            });

            it('should lock erc721', async () => {
                await expect(vault.lockAssetWithSalt(saltedLockData))
                    .to.emit(vault, 'Locked')
                    .withArgs([
                        saltedLockData.tokenType,
                        saltedLockData.token,
                        saltedLockData.tokenId,
                        saltedLockData.extAccount,
                        saltedLockData.extAmount,
                    ]);
            });
        });

        describe('Erc1155', () => {
            before(async () => {
                const tokenId = 333;
                const amount = 1;
                token = await (
                    await ethers.getContractFactory('MockERC1155')
                ).deploy();
                await token.mint(extAccount.address, tokenId, amount, '0x');
                tokenType = TokenType.Erc1155;
                saltedLockData = {
                    tokenType: tokenType,
                    token: token.address,
                    tokenId: tokenId,
                    salt: salt,
                    extAccount: extAccount.address,
                    extAmount: amount,
                };

                stealthAddress = composeERC20SenderStealthAddress(
                    saltedLockData,
                    vault.address,
                );

                await token
                    .connect(extAccount)
                    .setApprovalForAll(stealthAddress, true);

                const approved = await token.isApprovedForAll(
                    extAccount.address,
                    stealthAddress,
                );

                await expect(approved).eq(true);
            });

            it('should lock erc1155', async () => {
                await expect(vault.lockAssetWithSalt(saltedLockData))
                    .to.emit(vault, 'Locked')
                    .withArgs([
                        saltedLockData.tokenType,
                        saltedLockData.token,
                        saltedLockData.tokenId,
                        saltedLockData.extAccount,
                        saltedLockData.extAmount,
                    ]);
            });
        });

        describe('Native token', () => {
            const amount = ethers.constants.WeiPerEther;
            beforeEach(async () => {
                tokenType = TokenType.Native;
                saltedLockData = {
                    tokenType: tokenType,
                    token: ADDRESS_ZERO,
                    tokenId: 0,
                    salt: salt,
                    extAccount: owner.address,
                    extAmount: amount,
                };
            });

            describe('if msg.value is zero', () => {
                before(async () => {
                    tokenType = TokenType.Native;
                    saltedLockData = {
                        tokenType: tokenType,
                        token: ADDRESS_ZERO,
                        tokenId: 0,
                        salt: salt,
                        extAccount: owner.address,
                        extAmount: amount,
                    };

                    const stealthAddress = await vault.getEscrowAddress(
                        salt,
                        owner.address,
                    );

                    await owner.sendTransaction({
                        to: stealthAddress,
                        value: amount,
                    });

                    await expect(
                        await ethers.provider.getBalance(stealthAddress),
                    ).gte(saltedLockData.extAmount);
                });

                it('should lock native token from escrow', async () => {
                    await expect(vault.lockAssetWithSalt(saltedLockData))
                        .to.emit(vault, 'Locked')
                        .withArgs([
                            saltedLockData.tokenType,
                            saltedLockData.token,
                            saltedLockData.tokenId,
                            saltedLockData.extAccount,
                            saltedLockData.extAmount,
                        ]);
                });
            });

            describe('if msg.value is NOT zero', () => {
                before(async () => {
                    await vault
                        .connect(owner)
                        .sendEthToEscrow(salt, {value: amount})
                        .then(tx => tx.wait());
                });

                it('should lock native token being sent with the tx', async () => {
                    await expect(vault.lockAssetWithSalt(saltedLockData))
                        .to.emit(vault, 'Locked')
                        .withArgs([
                            saltedLockData.tokenType,
                            saltedLockData.token,
                            saltedLockData.tokenId,
                            saltedLockData.extAccount,
                            saltedLockData.extAmount,
                        ]);
                });
            });
        });
    });

    describe('Fail cases', () => {
        describe('when lockAsset/unlockAsset by non owner', () => {
            before(() => {
                lockData = genLockData(TokenType.Erc20, erc20Token.address);
            });

            it('should revert on lock', async () => {
                await expect(
                    vault.connect(extAccount).lockAsset(lockData),
                ).to.be.revertedWith('ImmOwn: unauthorized');
            });

            it('should revert on unlock', async () => {
                await expect(
                    vault.connect(extAccount).unlockAsset(lockData),
                ).to.be.revertedWith('ImmOwn: unauthorized');
            });
        });

        describe('when lockAsset/unlockAsset unknown token', () => {
            before(() => {
                lockData = genLockData(TokenType.unknown, erc20Token.address);
            });

            it('should revert on lock', async () => {
                await expect(vault.lockAsset(lockData)).to.be.revertedWith(
                    'VA:E1',
                );
            });

            it('should revert on unlock', async () => {
                await expect(vault.unlockAsset(lockData)).to.be.revertedWith(
                    'VA:E1',
                );
            });
        });

        describe('when lockAsset/unlockAsset token with zero token address', () => {
            before(() => {
                lockData = genLockData(TokenType.Erc20, erc20Token.address);
                lockData.token = ethers.constants.AddressZero;
            });

            it('should revert on lock', async () => {
                await expect(vault.lockAsset(lockData)).to.be.revertedWith(
                    'VA:E2',
                );
            });

            it('should revert on unlock', async () => {
                await expect(vault.unlockAsset(lockData)).to.be.revertedWith(
                    'VA:E2',
                );
            });
        });

        describe('when lockAsset/unlockAsset with zero receiver address', () => {
            before(() => {
                lockData = genLockData(TokenType.Erc20, erc20Token.address);
                lockData.extAccount = ethers.constants.AddressZero;
            });

            it('should revert on lock', async () => {
                await expect(vault.lockAsset(lockData)).to.be.revertedWith(
                    'VA:E3',
                );
            });

            it('should revert on unlock', async () => {
                await expect(vault.unlockAsset(lockData)).to.be.revertedWith(
                    'VA:E3',
                );
            });
        });

        describe('when lockAsset/unlockAsset with zero lockData.extAmount', () => {
            before(() => {
                lockData = genLockData(TokenType.Erc20, erc20Token.address);
                lockData.extAmount = toBigNum(0);
            });

            it('should revert on lock', async () => {
                await expect(vault.lockAsset(lockData)).to.be.revertedWith(
                    'VA:E4',
                );
            });

            it('should revert on unlock', async () => {
                await expect(vault.unlockAsset(lockData)).to.be.revertedWith(
                    'VA:E4',
                );
            });
        });
    });

    function genLockData(tokenType: number, tokenAddress: string): LockData {
        return {
            tokenType: tokenType,
            token: tokenAddress,
            // For ERC-20 and the native token, tokenId must be 0
            tokenId:
                tokenType == TokenType.Erc20 || tokenType == TokenType.Native
                    ? toBigNum(0)
                    : toBigNum(Math.floor(Math.random() * 1e12)),
            extAccount: extAccount.address,
            // For ERC-721 the extAmount must be exactly 1
            extAmount:
                tokenType == TokenType.Erc721
                    ? toBigNum(1)
                    : toBigNum(Math.floor(Math.random() * 10000) + 1),
        };
    }

    function extendLockDataWithSalt(lockData: LockData): SaltedLockDataStruct {
        // Random 64-bytes hex string
        const salt =
            '0x' +
            (crypto.randomUUID() + crypto.randomUUID()).replace(/-/g, '');
        return Object.assign({salt}, lockData);
    }

    type LockData = {
        tokenType: number;
        token: string;
        tokenId: BigNumber;
        extAccount: string;
        extAmount: BigNumber;
    };
});
