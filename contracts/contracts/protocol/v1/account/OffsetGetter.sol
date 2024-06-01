// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar

/**
 * @title OffsetGetter
 * @author Pantherprotocol Contributors
 * @dev This contract allows for efficient storage and retrieval of
 * offsets associated with specific target addresses and function selectors,
 * providing a mechanism for managing complex function call IDs.
 */

pragma solidity ^0.8.19;

contract OffsetGetter {
    uint256 public immutable ID_1;
    uint256 public immutable ID_2;
    uint256 public immutable ID_3;
    uint256 public immutable ID_4;
    uint256 public immutable ID_5;
    uint256 public immutable ID_6;
    uint256 public immutable ID_7;
    uint256 public immutable ID_8;

    /**
     * @dev Constructor to initialize the contract with target addresses, function selectors, and offsets.
     * @param targets Array of target addresses for function calls.
     * @param selectors Array of function selectors (signatures) for function calls.
     * @param offsets Array of offsets associated with each function call.
     */
    constructor(
        address[8] memory targets,
        bytes4[8] memory selectors,
        uint32[8] memory offsets
    ) {
        require(
            targets.length == 8 && selectors.length == 8 && offsets.length == 8,
            "Invalid input length"
        );

        ID_1 = createComplexID(targets[0], selectors[0], offsets[0]);
        ID_2 = createComplexID(targets[1], selectors[1], offsets[1]);
        ID_3 = createComplexID(targets[2], selectors[2], offsets[2]);
        ID_4 = createComplexID(targets[3], selectors[3], offsets[3]);
        ID_5 = createComplexID(targets[4], selectors[4], offsets[4]);
        ID_6 = createComplexID(targets[5], selectors[5], offsets[5]);
        ID_7 = createComplexID(targets[6], selectors[6], offsets[6]);
        ID_8 = createComplexID(targets[7], selectors[7], offsets[7]);
    }

    /**
     * @dev Check if the given target, selector, and offset combination is included in the contract's storage.
     * @param target Target address for the function call.
     * @param selector Function selector (signature) for the function call.
     * @param offset Offset associated with the function call.
     * @return Boolean indicating whether the combination is included.
     */
    function isIncluded(
        address target,
        bytes4 selector,
        uint32 offset
    ) external view returns (bool) {
        uint256 complexID = createComplexID(target, selector, offset);
        return
            complexID == ID_1 ||
            complexID == ID_2 ||
            complexID == ID_3 ||
            complexID == ID_4 ||
            complexID == ID_5 ||
            complexID == ID_6 ||
            complexID == ID_7 ||
            complexID == ID_8;
    }

    /**
     * @dev function to get the offset associated with a given target and selector.
     * @param target Target address for the function call.
     * @param selector Function selector (signature) for the function call.
     * @return Offset associated with the given target and selector.
     */
    function getOffset(
        address target,
        bytes4 selector
    ) internal view returns (uint32) {
        uint256 complexID = createComplexID(target, selector, 0); // We set offset to 0 for comparison
        uint256[8] memory ids = [
            ID_1,
            ID_2,
            ID_3,
            ID_4,
            ID_5,
            ID_6,
            ID_7,
            ID_8
        ];

        for (uint256 i = 0; i < ids.length; i++) {
            if (
                (complexID >> 96) == (ids[i] >> 96) &&
                ((complexID >> 64) & 0xFFFFFFFF) ==
                ((ids[i] >> 64) & 0xFFFFFFFF)
            ) {
                return uint32(ids[i]);
            }
        }

        return 0;
    }

    /**
     * @dev function to create a complex ID combining target, selector, and offset.
     * @param target Target address for the function call.
     * @param selector Function selector (signature) for the function call.
     * @param offset Offset associated with the function call.
     * @return id Complex ID representing the combination of target, selector, and offset.
     **/
    function createComplexID(
        address target,
        bytes4 selector,
        uint32 offset
    ) internal pure returns (uint256 id) {
        return
            (uint256(uint160(target)) << 96) |
            (uint256(uint32(selector)) << 64) |
            uint256(offset);
    }

    /**
     * @dev function to extract a uint256 value from callData by a given offset.
     * @param callData Call data containing the encoded function call.
     * @param offset Offset to extract value from callData.
     * @return result Extracted uint256 value.
     */

    function _exctractBytesByOffset(
        bytes memory callData,
        uint256 offset
    ) internal pure returns (uint256 result) {
        require(callData.length > offset, "short data");
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Add 32 to skip the first 32 bytes which store the length of the `bytes` array
            result := mload(add(add(callData, 0x20), offset))
        }
    }
}
