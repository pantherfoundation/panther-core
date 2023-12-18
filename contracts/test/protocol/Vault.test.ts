// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import crypto from 'crypto';

import {FakeContract, smock} from '@defi-wonderland/smock';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import chai, {expect} from 'chai';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {toBigNum} from '../../lib/utilities';
import {
    Vault,
    IMockErc20,
    IMockErc721,
    IMockErc1155,
} from '../../types/contracts';

chai.use(smock.matchers);

describe('Vault contract', function () {
    let vault: Vault;
    let erc20Token: FakeContract<IMockErc20>;
    let erc721Token: FakeContract<IMockErc721>;
    let erc1155Token: FakeContract<IMockErc1155>;
    let owner: SignerWithAddress;
    let extAccount: SignerWithAddress;
    let lockData: LockData;
    let saltedLockData: SaltedLockData;

    const oneEth = ethers.constants.WeiPerEther;
    const TokenType = {
        Erc20: 0x00,
        Erc721: 0x10,
        Erc1155: 0x11,
        Native: 0xff,
        unknown: 0x99,
    };

    before(async function () {
        [owner, extAccount] = await ethers.getSigners();

        const Vault = await ethers.getContractFactory('Vault');
        vault = (await Vault.deploy(owner.address)) as Vault;

        erc20Token = await smock.fake('IMockErc20');
        erc721Token = await smock.fake('IMockErc721');
        erc1155Token = await smock.fake('IMockErc1155');
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

    // TODO: implement tests for 'function lockAssetWithSalt'
    describe.skip('function lockAssetWithSalt', () => {
        describe('Erc20', () => {
            before(() => {
                erc20Token.transferFrom.returns(true);
                erc20Token.transfer.returns(true);

                saltedLockData = extendLockDataWithSalt(
                    genLockData(TokenType.Erc20, erc20Token.address),
                );
            });

            it('should lock erc20', async () => {
                await expect(vault.lockAssetWithSalt(saltedLockData))
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

                saltedLockData = extendLockDataWithSalt(
                    genLockData(TokenType.Erc721, erc721Token.address),
                );
            });

            it('should lock erc721', async () => {
                await expect(vault.lockAssetWithSalt(saltedLockData))
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

                saltedLockData = extendLockDataWithSalt(
                    genLockData(TokenType.Erc1155, erc1155Token.address),
                );
            });

            it('should lock erc1155', async () => {
                await expect(vault.lockAssetWithSalt(saltedLockData))
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

        // TODO: implement tests for the native token lock with 'function lockAssetWithSalt'
        describe('Native token', () => {
            describe('if msg.value is zero', () => {
                it('should lock native token from escrow', async () => {});
            });

            describe('if msg.value is NOT zero', () => {
                it('should lock native token being sent with the tx', async () => {});
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

        describe('when lockAsset/unlockAsset with zero amount', () => {
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

    function extendLockDataWithSalt(lockData: LockData): SaltedLockData {
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

    type SaltedLockData = {
        tokenType: number;
        token: string;
        tokenId: BigNumber;
        salt: string;
        extAccount: string;
        extAmount: BigNumber;
    };
});
