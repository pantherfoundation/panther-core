// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable one-contract-per-file
// solhint-disable max-line-length
pragma solidity ^0.8.19;

import { DelegatecallAware } from "../../../common/DelegatecallAware.sol";
import { Multicall } from "../../../common/Multicall.sol";
import { StealthDelegate } from "../vault/StealthDelegate.sol";

contract MockStealthDelegate is DelegatecallAware, Multicall, StealthDelegate {
    function delegatedMulticall(
        bytes[] calldata data
    )
        public
        payable
        onlyDelegatecalled
        returns (
            // onlyDelegatecalledAfterSelfCall
            bytes[] memory results
        )
    {
        // console.log("delegatedMulticall");
        return _multicall(data);
    }
}
// solhint-disable max-line-length
/*
// TODO: write u-tests for MockStealthDelegate
// based on / using this example

let signer = await ethers.getSigner()
let test = await ethers.getContractFactory('Test153').then(c => c.deploy())
let target = await ethers.getContractFactory('Test152_Target').then(c => c.deploy())
salt = '0xc0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fe'

/// Calls flow:
// EOA->CALL[1]->test::stealthDelegate->DELEGATECALL[2]->test::delegatedMulticall->(CALL[3,4,5]->target::increment)

/// Let's call via `test.stealthDelegate`
sel3 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('increment()')).substr(0,10)
let calldata3 = ethers.utils.defaultAbiCoder.encode(['address', 'bytes'], [target.address, sel3])

sel2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('delegatedMulticall(bytes[])')).substr(0,10)
let calldata2 = sel2 + ethers.utils.defaultAbiCoder.encode(['bytes[]'], [[calldata3, calldata3, calldata3]]).replace('0x', '')
console.log(`calldata2.length: ${(calldata2.length - 2)/2} bytes`) // calldata2.length: 644 bytes

let tx1 = await test.stealthDelegate(0, salt, test.address, calldata2)
(await target.counter()).toNumber() // 3
(await tx1.wait()).gasUsed.toNumber() // 97166

/// Same call as tx1 is, but via `signer.sendTransaction`
sel1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('stealthDelegate(uint256,bytes32,address,bytes)')).substr(0,10)
let calldata1 = sel1 + ethers.utils.defaultAbiCoder.encode(['uint256','bytes32','address','bytes'], [0, salt, test.address, calldata2]).replace('0x', '')
console.log(`calldata1.length: ${(calldata1.length - 2)/2} bytes`) // calldata1.length: 836 bytes

let tx2 = await signer.sendTransaction({to: test.address, data: calldata1})
(await target.counter()).toNumber() // 6
(await tx2.wait()).gasUsed.toNumber() // 80066
*/
// solhint-enable max-line-length
