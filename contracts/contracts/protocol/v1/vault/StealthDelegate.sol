// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

abstract contract StealthDelegate {
    // @dev Execute the DELEGATECALL to `delegateAddr` with `data` as calldata.
    // The executing account (`address(this)`) inside the DELEGATECALL will be
    // the "stealthDelegate" address.
    function stealthDelegate(
        uint256 amount,
        bytes32 salt,
        address delegateAddr,
        bytes calldata data
    ) external returns (address) {
        // console.log("stealthDelegate to: %s", delegateAddr);
        bytes memory bytecode = getStealthDelegatorInitCode(delegateAddr, data);
        // console.log("executing CREATE2");
        return Create2.deploy(amount, salt, bytecode);
    }

    // @dev Compute (deterministically) the address of the StealthDelegator
    function computeStealthDelegatorAddress(
        bytes32 salt,
        address delegateAddr,
        bytes calldata data
    ) external view returns (address) {
        bytes memory bytecode = getStealthDelegatorInitCode(delegateAddr, data);
        return Create2.computeAddress(salt, keccak256(bytecode));
    }

    /***
       @dev It returns the creation code of the "StealthDelegator" "contract".

       StealthDelegator is an unusual contract: just like any other contract,
       it has the creation code, but its runtime bytecode is never deployed.
       It is "delegator" since it executes the DELAGATECALL with given params.
       It is "stealth" as it runs (when called via CREATE or CREATE2) during
       the "deployment" only, and then it "disappears".

       When the "deployer" (the account executing CREATE or CREATE2) calls this
       creation code, the code does NOT create any new contracts, but instead:
       - executes the DELEGATECALL with the given `to` and `data`, and then ...
       - self-destructs, sending remaining native token balance to the deployer.

       Users may be sure that, inside the DELEGATECALL:
       - caller (`msg.sender`) is always the deployer
       - executing account (`address(this)`), if the deployer executes CREATE2,
         may be deterministically computed before the "deployment".
     */
    function getStealthDelegatorInitCode(
        address delegateAddr,
        bytes calldata data
    ) public pure returns (bytes memory) {
        /***
        =Offs =Bytecode =Opcode          =Stack                                      =Memory

        // Copy <addr> from code to stack
        [00]  3d        RETURNDATASIZE   0                                           -
        [01]  6014      PUSH1 14         14,0                                        -
        [03]  602a      PUSH1 addrOffs   addrOffs,14,0                               -
        [05]  3d        RETURNDATASIZE   0,addrOffs,14,0                             -
                                         // stack_expected:destOffs,ofs,size
        [06]  39        CODECOPY         0                                           [0,14]=addr<<60
                                         // stack_expected:offset
        [07]  51        MLOAD            addr<<60                                    [0,14]=addr<<60
        [08]  6060      PUSH 60          60,addr<<60                                 [0,14]=addr<<60
        [0a]  1C        SHR              addr                                        [0,14]=addr<<60
        // Add 0,0 to stack bottom (optimization)
        [0b]  3d        RETURNDATASIZE   0,addr                                      [0,14]=addr<<60
        [0c]  3d        RETURNDATASIZE   0,0,addr                                    [0,14]=addr<<60
        // Put <data> size to stack and copy <data> to memory
        [0d]  603e      PUSH1 dataOffs   dataOffs,0,0,addr                           [0,14]=addr<<60
        [0f]  80        DUP1             dataOffs,dataOffs,0,0,addr                  [0,14]=addr<<60
        [10]  38        CODESIZE         cs,dataOffs,dataOffs,0,0,addr               [0,14]=addr<<60
        [11]  03        SUB              cs-dataOffs,dataOffs,0,0,addr               [0,14]=addr<<60
        [12]  80        DUP1             cs-dataOffs,cs-dataOffs,dataOffs,0,0,addr   [0,14]=addr<<60
        [13]  91        SWAP2            dataOffs,cs-dataOffs,cs-dataOffs,0,0,addr   [0,14]=addr<<60
        [14]  3d        RETURNDATASIZE   0,dataOffs,cs-dataOffs,cs-dataOffs,0,0,addr [0,14]=addr<<60
                                         // stack_expected:destOffs,ofs,size
        [15]  39        CODECOPY         cs-dataOffs,0,0,addr                        [0,cs-dataOffs]=data
        // Delegatecall <addr> with <data>
        [16]  3d        RETURNDATASIZE  0,cs-dataOffs,0,0,addr                       [0,cs-dataOffs]=data
        [17]  3d        RETURNDATASIZE  0,0,cs-dataOffs,0,0,addr                     [0,cs-dataOffs]=data
        [18]  94        SWAP5           addr,0,cs-dataOffs,0,0,0                     [0,cs-dataOffs]=data
        [19]  5a        GAS             gas,addr,0,cs-dataOffs,0,0,0                 [0,cs-dataOffs]=data
                                        // stack_expected:gas,addr,argOffs,argSize,retOffs,retSize
        [1a]  f4        DELEFATECALL    success,0                                    [0,cs-dataOffs]=data
        [1b]  6025      PUSH1 dest      dest,success,0                               [0,cs-dataOffs]=data
        [1d]  57        JUMPI           0                                            [0,cs-dataOffs]=data
        // Revert on !success
        [1e]  3d        RETURNDATASIZE  rds,0                                        [0,cs-dataOffs]=data
        [1f]  90        SWAP1           0,rds                                        [0,cs-dataOffs]=data
        [20]  81        DUP2            rds,0,rds                                    [0,cs-dataOffs]=data
        [21]  81        DUP2            0,rds,0,rds                                  [0,cs-dataOffs]=data
        [22]  80        DUP1            0,0,rds,0,rds                                [0,cs-dataOffs]=data
                                        // stack_expected:destOffset,offset,size
        [23]  3e        RETURNDATACOPY  0,rds                                        [0,rds]=ret_data
                                        // stack_expected:offset,size
        [24]  fd        REVERT          –                                            [0,rds]=ret_data
        // Destroy contract & transfer balance to caller
        [25]  5b        JUMPDEST        0                                            [0,cs-dataOffs]=data
        [26]  50        POP             -                                            [0,cs-dataOffs]=data
        [27]  33        CALLER          caller                                       [0,cs-dataOffs]=data
        [28]  ff        SELFDESTRUCT    -                                            -
        [29]  00        STOP            -                                            -
        // 0x3d6014602a3d395160601C3d3d603e80380380913d393d3d945af46025573d908181803efd5b5033ff00

        // Appended 20 bytes of `delegateAddr` addr and ("packed") `data` bytes
        // addrOffs=[2a]
        [2a]  <addr>
        // dataOffs=[3e]
        [3e]  <data>

        / -- OPTION 2 (unused) - w/o self-destruction
        // Return empty runtime code on success
        [25]  5b        JUMPDEST        0                                            [0,cs-dataOffs]=data
        [26]  80        DUP1            0,0                                          [0,cs-dataOffs]=data
                                        // stack_expected:offset,size
        [27]  f3        RETURN          0                                            [0,cs-dataOffs]=data
        [28]  00        STOP            -                                            [0,cs-dataOffs]=data
        [29]  00        STOP            -                                            [0,cs-dataOffs]=data
        // 0x3d6014602a3d395160601C3d3d603e80380380913d393d3d945af46025573d908181803efd5b80f30000

        // Appended 20 bytes of `delegateAddr` addr and ("packed") `data` bytes
        // addrOffs=[2a]
        [2a]  <addr>
        // dataOffs=[3e]
        [3e]  <data>
        --/
        */
        return
            abi.encodePacked(
                hex"3d6014602a3d395160601C3d3d603e80380380913d393d3d945af46025573d908181803efd5b5033ff00",
                delegateAddr,
                data
            );
    }
}
