// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// SPDX-FileCopyrightText: Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SSTORE2.sol)
pragma solidity ^0.8.19;

/**
 * @notice Read bytecode at given address from given position.
 */
library Bytecode {
    function read(
        address pointer,
        uint256 offset
    ) internal view returns (bytes memory data) {
        uint256 size = pointer.code.length;
        require(size >= offset, "OUT_OF_BOUNDS");

        unchecked {
            size -= offset;
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Get a pointer to some free memory.
            data := mload(0x40)

            // Update the free memory pointer to prevent overriding our data.
            // We use and(x, not(31)) as a cheaper equivalent to sub(x, mod(x, 32)).
            // Adding 31 to size and running the result through the logic above ensures
            // the memory pointer remains word-aligned, following the Solidity convention.
            mstore(0x40, add(data, and(add(add(size, 32), 31), not(31))))

            // Store the size of the data in the first 32 byte chunk of free memory.
            mstore(data, size)

            // Copy the code into memory right after the 32 bytes we used to store the size.
            extcodecopy(pointer, add(data, 32), offset, size)
        }
    }
}
