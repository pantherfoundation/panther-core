// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

abstract contract StealthExecutor {
    /***
       @dev It returns the creation code of the "stealthExec" "contract" which, being called
       during the "deployment":
       - unlike creation code of a "normal" contract, does not actually create a new contract
       - executes the CALL to the given `to` and with the given `data`
       - self-destructs in the end, sending remaining native token balance to the "deployer".

       So, this code runs inside the CREATE or CREATE2 call and gets destroyed in the end.

       Being "deployed" via CREATE2, the caller (msg.sender) inside the CALL `to` may be
       computed (deterministically), before the "deployment", from the CREATE2's salt, and
       the given `to` and `data`.
     */
    function getStealthExecInitCode(
        address to,
        bytes calldata data
    ) public pure returns (bytes memory) {
        /*
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
        // Call <addr> with <data>
        [16]  3d        RETURNDATASIZE  0,cs-dataOffs,0,0,addr                       [0,cs-dataOffs]=data
        [17]  34        CALLVALUE       val,0,cs-dataOffs,0,0,addr                   [0,cs-dataOffs]=data
        [18]  3d        RETURNDATASIZE  0,val,0,cs-dataOffs,0,0,addr                 [0,cs-dataOffs]=data
        [19]  95        SWAP6           addr,val,0,cs-dataOffs,0,0,0                 [0,cs-dataOffs]=data
        [1a]  5a        GAS             gas,addr,val,0,cs-dataOffs,0,0,0             [0,cs-dataOffs]=data
                                        // stack_expected:gas,addr,val,argOffs,argSize,retOffs,retSize
        [1b]  f1        CALL            success,0                                    [0,cs-dataOffs]=data
        [1c]  6026      PUSH1 dest      dest,success,0                               [0,cs-dataOffs]=data
        [1e]  57        JUMPI           0                                            [0,cs-dataOffs]=data
        // Revert on !success
        [1f]  3d        RETURNDATASIZE  rds,0                                        [0,cs-dataOffs]=data
        [20]  90        SWAP1           0,rds                                        [0,cs-dataOffs]=data
        [21]  81        DUP2            rds,0,rds                                    [0,cs-dataOffs]=data
        [22]  81        DUP2            0,rds,0,rds                                  [0,cs-dataOffs]=data
        [23]  80        DUP1            0,0,rds,0,rds                                [0,cs-dataOffs]=data
                                        // stack_expected:destOffset,offset,size
        [24]  3e        RETURNDATACOPY  0,rds                                        [0,rds]=ret_data
                                        // stack_expected:offset,size
        [25]  fd        REVERT          –                                            [0,rds]=ret_data
        // Destroy contract & transfer balance to caller
        [26]  5b        JUMPDEST        0                                            [0,cs-dataOffs]=data
        [27]  50        POP             -                                            [0,cs-dataOffs]=data
        [28]  33        CALLER          caller                                       [0,cs-dataOffs]=data
        [29]  FF        SELFDESTRUCT    -                                            -
        [2a]  00        STOP            -                                            -
        // Appended 20 bytes of `to` addr and ("packed") `data` bytes
        [2b]  <addr>
        [3f]  <data>

        / -- OPTION 2 (unused) - w/o self-destruction
        // Return empty runtime code on success
        [26]  5b        JUMPDEST        0                                            [0,cs-dataOffs]=data
        [27]  80        DUP1            0,0                                          [0,cs-dataOffs]=data
                                        // stack_expected:offset,size
        [28]  f3        RETURN          0                                            [0,cs-dataOffs]=data
        [29]  00        STOP            -                                            [0,cs-dataOffs]=data
        // Appended 20 bytes of `to` addr and ("packed") `data` bytes
        [2a]  <addr>
        [3e]  <data>
        // 0x3d6014602a3d395160601C3d3d603e80380380913d393d343d955af16026573d908181803efd5b80f300<addr><data>
        --/
        */
        return
            abi.encodePacked(
                hex"3d6014602b3d395160601C3d3d603f80380380913d393d343d955af16026573d908181803efd5b5033ff00",
                to,
                data
            );
    }

    // @dev Compute (deterministic) "stealthExec" address
    function computeStealthExecAddress(
        bytes32 salt,
        address to,
        bytes calldata data
    ) external view returns (address) {
        bytes32 bytecodeHash = keccak256(getStealthExecInitCode(to, data));
        return Create2.computeAddress(salt, bytecodeHash);
    }

    // @dev Execute the CALL `to` with `data` from the "stealthExec" address
    function _stealthExec(
        uint256 amount,
        bytes32 salt,
        address to,
        bytes calldata data
    ) internal returns (address) {
        return Create2.deploy(amount, salt, getStealthExecInitCode(to, data));
    }
}
