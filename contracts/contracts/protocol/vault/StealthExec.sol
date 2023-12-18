// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

/***
  @title StealthExec library
  @notice Library to execute the `CALL` from a "stealth" account defined by the "salt".

  @dev In order to execute the CALL with the caller address (`msg.sender`) different than
  the account invoking this library, the library code "deploys" at that address a special
  contract, "StealthCaller", the creation code ("init code") of which executes the CALL.
  The StealthCaller is an unusual ("stealth") contract. Its runtime code ("deployed code")
  does not exist - the creation code leaves no bytecode at all to deploy on the chain. The
  `CALL` execution, rather than the runtime code deployment, is the sole purpose of the
  creation code invocation.
  The caller (`msg.sender`) inside the `CALL` is the address of the StealthCaller. This
  address is computable upfront and linked to the address to be CALLed and the call data -
  thanks to the `CREATE2` that invokes the creation code.
  Precisely, this address is a function of the following known in advance params:
  - the hash of the creation code (which the `CALL` address and data is a part of)
  - contract address that calls the `function callWithSalt`
  - (user-defined) `salt` provided on the `callWithSalt` function call.
  */
library StealthExec {
    /// @dev Execute the CALL with given params and from the deterministic `msg.sender`
    /// @param salt The salt (to deterministically derive the unique `msg.sender`)
    /// @param to The contract (address) to CALL to
    /// @param data The call data to CALL with
    /// @param value Wei amount to CALL with
    /// @return Caller address (`msg.sender` inside the CALL)
    function stealthCall(
        bytes32 salt,
        address to,
        bytes memory data,
        uint256 value
    ) internal returns (address) {
        bytes memory initCode = _getStealthCallerInitCode(to, data);
        // Execute `initCode` in the context of the newly created contract
        return Create2.deploy(value, salt, initCode);
    }

    /// @dev Compute the deterministic `msg.sender` for the params given
    /// @param salt The salt (to deterministically derive a unique `msg.sender`)
    /// @param to The contract address to CALL to
    /// @param data The call data to CALL with
    /// @return Caller address (`msg.sender` inside the CALL)
    function getStealthAddr(
        bytes32 salt,
        address to,
        bytes memory data
    ) internal view returns (address) {
        bytes32 initCodeHash = keccak256(_getStealthCallerInitCode(to, data));
        return Create2.computeAddress(salt, initCodeHash);
    }

    // It returns the creation code of the StealthCaller "contract" with given params.
    //  Being invoked via CREATE2 this creation code subsequently executes:
    //  - `CALL` to the given address with the given call data from the context of the
    //    "contract" being created (as `msg.sender`), passing all `GAS` and `CALLVALUE`
    //  - return without generating the runtime code to deploy.
    // (`CREATE` would also work, but `msg.sender` is not deterministic then)
    function _getStealthCallerInitCode(
        address to,
        bytes memory data
    ) private pure returns (bytes memory) {
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
        // Return empty runtime code on success
        [26]  5b        JUMPDEST        0                                            [0,cs-dataOffs]=data
        [27]  80        DUP1            0,0                                          [0,cs-dataOffs]=data
                                        // stack_expected:offset,size
        [28]  f3        RETURN          0                                            [0,cs-dataOffs]=data
        [29]  00        STOP            -                                            [0,cs-dataOffs]=data

        // Appended 20 bytes of `to` addr and ("packed") `data` bytes
        [2a]  <addr>
        [3e]  <data>
        */
        return
            abi.encodePacked(
                hex"3d6014602a3d395160601C3d3d603e80380380913d393d343d955af16026573d908181803efd5b80f300",
                to,
                data
            );
    }
}
