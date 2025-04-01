// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
pragma solidity ^0.8.19;

import { RevertMsgGetter } from "./misc/RevertMsgGetter.sol";

string constant ERR_ZERO_TO_ADDR = "MC:E2";

contract Multicall is RevertMsgGetter {
    function multicall(
        bytes[] calldata data
    ) public returns (bytes[] memory results) {
        results = new bytes[](data.length);

        for (uint256 i = 0; i < data.length; i++) {
            (address to, bytes memory _data) = abi.decode(
                data[i],
                (address, bytes)
            );

            require(to != address(0), ERR_ZERO_TO_ADDR);

            (bool success, bytes memory result) = to.call(_data);

            if (!success) revert(getRevertMsg(result));

            results[i] = result;
        }
    }
}

/*
// TODO: Analyze possible optimization: tight calldata packing

// Current calldata packing (for 3 x target::increment() calls),
// Size: 4 bytes + 20 x 32-byte slots
0xefcd46ee  // selector for `delegatedMulticall(bytes[])`
[000      ]  0000000000000000000000000000000000000000000000000000000000000020 // bytes[] offset
[020      ]  0000000000000000000000000000000000000000000000000000000000000003 // bytes[] size
[040 (000)]  0000000000000000000000000000000000000000000000000000000000000060 // bytes[0] offset
[060 (020)]  0000000000000000000000000000000000000000000000000000000000000100 // bytes[1] offset
[080 (040)]  00000000000000000000000000000000000000000000000000000000000001a0 // bytes[2] offset

[0a0 (060)]  0000000000000000000000000000000000000000000000000000000000000080 // bytes[0] size
[0c0 (080)]  000000000000000000000000d15ee89dd37e62d131e382c8df7911ce872bf74d // 1st call address
[0e0 (0a0)]  0000000000000000000000000000000000000000000000000000000000000040 // 1st call bytes' offset
[100 (0c0)]  0000000000000000000000000000000000000000000000000000000000000004 // 1st call bytes' size
[120 (0e0)]  d09de08a00000000000000000000000000000000000000000000000000000000 // 1st call bytes

[140 (100)]  0000000000000000000000000000000000000000000000000000000000000080 // bytes[1] size
[160 (120)]  000000000000000000000000d15ee89dd37e62d131e382c8df7911ce872bf74d // 2nd call ...
[180 (140)]  0000000000000000000000000000000000000000000000000000000000000040
[1a0 (160)]  0000000000000000000000000000000000000000000000000000000000000004
[1c0 (180)]  d09de08a00000000000000000000000000000000000000000000000000000000

[1e0 (1a0)]  0000000000000000000000000000000000000000000000000000000000000080 // bytes[2] size
[200 (1c0)]  000000000000000000000000d15ee89dd37e62d131e382c8df7911ce872bf74d // 3rd call ...
[220 (1e0)]  0000000000000000000000000000000000000000000000000000000000000040
[240 (200)]  0000000000000000000000000000000000000000000000000000000000000004
[260 (220)]  d09de08a00000000000000000000000000000000000000000000000000000000

// calldata for same 3 x target::increment() calls if serialized tightly
// Size: 158 + 4 bytes
0xefcd46ee // selector for `delegatedMulticall(bytes[])`
[000] 03 // Number of calls encoded in `bytes[]`
[001] 0007 // 1st call's calldata offset
[003] 001f // 2nd -"-
[005] 0037 // 3rd -"-
[007] d15ee89dd37e62d131e382c8df7911ce872bf74d d09de08a // 1st call's calldata: address (20 bytes) + calldata (rest)
[01f] d15ee89dd37e62d131e382c8df7911ce872bf74d d09de08a // 2nd -"-
[037] d15ee89dd37e62d131e382c8df7911ce872bf74d d09de08a // 3rd -"-
*/
