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
try { await escrow.connect(carol).withdrawEthFromEscrow(salt).then(tx => tx.wait()); } catch(e) { console.log('failed as expected')}

const rcp4 = await escrow.connect(bob).withdrawEthFromEscrow(salt).then(tx => tx.wait())
assert(await ethers.provider.getBalance(ea1) == BigInt(0))
try { await escrow.connect(bob).withdrawEthFromEscrow(salt).then(tx => tx.wait()); } catch(e) { console.log('failed as expected')}

const rcp5 = await escrow.internalPullEthFromEscrow(salt, bob.address, 0).then(tx => tx.wait())
assert(await ethers.provider.getBalance(escrow.address) == BigInt(0))

const ea2 = await escrow.getEscrowAddress(salt, alice.address)
const rcp6 = await escrow.connect(alice).sendEthToEscrow(salt, {value: 5e12}).then(tx => tx.wait())
assert(await ethers.provider.getBalance(ea2) == BigInt(5e12))

const rcp7 = await escrow.internalPullEthFromEscrow(salt, alice.address, 5e12).then(tx => tx.wait())
assert(await ethers.provider.getBalance(ea2) == BigInt(0))
assert(await ethers.provider.getBalance(escrow.address) == BigInt(5e12))
*/
