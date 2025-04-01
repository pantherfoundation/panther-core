// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

/* TODO: write tests using this (or similar) scenario

//// MockEthEscrow test
const [deployer, alice, bob, carol] = await ethers.getSigners()
const escrow = await ethers.getContractFactory('MockEthEscrow').then(c => c.deploy())

const salt = '0x0011223344556677889900112233445566778899001122334455667788990011'
const ea1 = await escrow.getEscrowAddress(salt, bob.address)
assert(await ethers.provider.getBalance(escrow.address) == BigInt(0))
assert(await ethers.provider.getBalance(ea1) == BigInt(0))

const rcp1 = await escrow.connect(bob).sendEthToEscrow(salt, {value: 1e12}).then(tx => tx.wait())
assert(await ethers.provider.getBalance(escrow.address) == BigInt(0))
assert(await ethers.provider.getBalance(ea1) == BigInt(1e12))

const rcp2 = await escrow.connect(bob).sendEthToEscrow(salt, {value: 2e12}).then(tx => tx.wait())
assert(await ethers.provider.getBalance(ea1) == BigInt(3e12))
try { await escrow.connect(carol).withdrawEthFromEscrow(salt).then(tx => tx.wait()); } catch(e) { // console.log('failed as expected')}

const rcp4 = await escrow.connect(bob).withdrawEthFromEscrow(salt).then(tx => tx.wait())
assert(await ethers.provider.getBalance(ea1) == BigInt(0))
try { await escrow.connect(bob).withdrawEthFromEscrow(salt).then(tx => tx.wait()); } catch(e) { // console.log('failed as expected')}

const rcp5 = await escrow.internalPullEthFromEscrow(salt, bob.address, 0).then(tx => tx.wait())
assert(await ethers.provider.getBalance(escrow.address) == BigInt(0))

const ea2 = await escrow.getEscrowAddress(salt, alice.address)
const rcp6 = await escrow.connect(alice).sendEthToEscrow(salt, {value: 5e12}).then(tx => tx.wait())
assert(await ethers.provider.getBalance(ea2) == BigInt(5e12))

const rcp7 = await escrow.internalPullEthFromEscrow(salt, alice.address, 5e12).then(tx => tx.wait())
assert(await ethers.provider.getBalance(ea2) == BigInt(0))
assert(await ethers.provider.getBalance(escrow.address) == BigInt(5e12))
*/

import {expect} from 'chai';

describe('EthEscrow', function () {
    let alice, bob, carol: SignerWithAddress;
    let escrow: any;
    let salt, ea1: string;
    const amount: number = 1e12;

    before(async function () {
        [alice, bob, carol] = await ethers.getSigners();
        salt =
            '0x0011223344556677889900112233445566778899001122334455667788990011';
    });

    context('send', () => {
        beforeEach(async function () {
            escrow = await ethers
                .getContractFactory('MockEthEscrow')
                .then(c => c.deploy());
            ea1 = await escrow.getEscrowAddress(salt, bob.address);
        });

        it('should sendEthToEscrow', async () => {
            expect(await ethers.provider.getBalance(ea1)).eq(0);

            await escrow
                .connect(bob)
                .sendEthToEscrow(salt, {value: amount})
                .then(tx => tx.wait());

            expect(await ethers.provider.getBalance(ea1)).eq(amount);
        });
    });

    context('withdraw', () => {
        beforeEach(async function () {
            escrow = await ethers
                .getContractFactory('MockEthEscrow')
                .then(c => c.deploy());

            ea1 = await escrow.getEscrowAddress(salt, bob.address);
            await escrow
                .connect(bob)
                .sendEthToEscrow(salt, {value: amount})
                .then(tx => tx.wait());
        });

        context('withdrawEthFromEscrow', () => {
            it('should revert when called not by depositor', async () => {
                await expect(
                    escrow.connect(carol).withdrawEthFromEscrow(salt),
                ).to.be.revertedWith('VE:E2');
            });

            it('should pull when called by depositor', async () => {
                const bal1 = await ethers.provider.getBalance(bob.address);

                await expect(
                    escrow.connect(bob).callStatic.withdrawEthFromEscrow(salt),
                ).to.be.not.reverted;

                const tx = await escrow
                    .connect(bob)
                    .withdrawEthFromEscrow(salt);

                const receipt = await tx.wait();

                const bal2 = await ethers.provider.getBalance(bob.address);

                expect(
                    bal1
                        .sub(receipt.gasUsed.mul(receipt.effectiveGasPrice))
                        .add(amount),
                ).eq(bal2);

                expect(await ethers.provider.getBalance(ea1)).eq(BigInt(0));
            });
        });

        context('internalPullEthFromEscrow', () => {
            it('should revert with wrong depositor address', async () => {
                await expect(
                    escrow.callStatic.internalPullEthFromEscrow(
                        salt,
                        alice.address,
                        amount,
                    ),
                ).to.be.revertedWith('PWS:E01');
            });

            it('should pull to contract address', async () => {
                expect(await ethers.provider.getBalance(ea1)).eq(amount);

                await expect(
                    escrow.callStatic.internalPullEthFromEscrow(
                        salt,
                        bob.address,
                        amount,
                    ),
                ).to.be.not.reverted;

                const tx = await escrow.internalPullEthFromEscrow(
                    salt,
                    bob.address,
                    amount,
                );
                await tx.wait();

                expect(await ethers.provider.getBalance(ea1)).eq(BigInt(0));

                expect(await ethers.provider.getBalance(escrow.address)).eq(
                    amount,
                );

                expect(await ethers.provider.getBalance(ea1)).eq(BigInt(0));
            });
        });
    });
});
