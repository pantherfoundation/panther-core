// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable no-inline-assembly
pragma solidity ^0.8.19;

uint256 constant UNISWAPV3_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH = 59;
uint256 constant UNISWAPV3_ROUTER_EXACT_INPUT_SINGLE_MINIMUM_LENGTH = 36;
uint256 constant QUICKSWAP_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH = 36;

library PluginDataDecoderLib {
    // getting the plugin address that is always the first 160 bits
    function extractPluginAddress(
        bytes memory data
    ) internal pure returns (address plugin) {
        require(data.length >= 20, "invalid length");

        assembly {
            let location := data

            let _data := mload(add(location, 0x20))
            plugin := shr(96, _data)
        }
    }

    /**
     * @notice Decodes data for Uniswap V3 router.
     * @param data The data to be decoded.
     * @dev **The data should be encoded as:
     * `abi.encodePacked(
     * address pluginAddress,
     * uint32 deadline,
     * uint96 amountOutMinimum,
     * uint24 fee,
     * uint160 sqrtPriceLimitX96)`.
     */
    function decodeUniswapV3RouterExactInputSingleData(
        bytes memory data
    )
        internal
        pure
        returns (
            uint32 deadline,
            uint96 amountOutMinimum,
            uint24 fee,
            uint160 sqrtPriceLimitX96
        )
    {
        require(
            data.length == UNISWAPV3_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH,
            "invalid length"
        );

        assembly {
            let location := data

            // skip the 160 bits for plugin address
            let pluginData_1 := mload(add(location, add(0x20, 0x14)))

            deadline := shr(224, pluginData_1)
            amountOutMinimum := and(
                shr(128, pluginData_1),
                0xffffffffffffffffffffffff
            )
            fee := and(shr(104, pluginData_1), 0xffffff)

            // skip 312 bits ( 160 (plugin) + 32(deadline) + 96(amountOutMinimum) + 24(fee) )
            let pluginData_2 := mload(add(location, add(0x20, 0x27)))
            sqrtPriceLimitX96 := and(
                0xffffffffffffffffffffffffffffffffffffffff,
                shr(96, pluginData_2)
            )
        }
    }

    function decodeUniswapV3RouterExactInputData(
        bytes memory data
    )
        internal
        pure
        returns (uint32 deadline, uint96 amountOutMinimum, bytes memory path)
    {
        require(
            data.length >= UNISWAPV3_ROUTER_EXACT_INPUT_SINGLE_MINIMUM_LENGTH,
            "invalid length"
        );

        assembly {
            let location := add(data, 0x20)
            //  let dataLength := mload(location)

            // skip the 160 bits for plugin address
            let pluginData_1 := mload(add(location, 0x14))

            deadline := shr(224, pluginData_1)
            amountOutMinimum := and(
                shr(128, pluginData_1),
                0xffffffffffffffffffffffff
            )

            // Calculate the length of the path data
            let pathStart := add(location, 0x24)
            let pathLength := sub(mload(data), 0x24)

            // Allocate memory for the path and set its length
            path := mload(0x40)
            mstore(path, pathLength)

            // Update the free memory pointer
            let pathMemoryEnd := add(add(path, 0x20), pathLength)
            mstore(0x40, pathMemoryEnd)

            // Copy the path data to the allocated memory
            // let pathData := add(path, 0x20)
            let pathLocation := add(path, 0x20)

            for {
                let i := 0
            } lt(i, pathLength) {
                i := add(i, 0x8)
            } {
                mstore(add(pathLocation, i), mload(add(pathStart, i)))
            }
        }
    }

    /**
     * @notice Decodes data for Uniswap V3 pool.
     * @param data The data to be decoded.
     * @dev The data should be encoded as:
     * `abi.encodePacked(
     * address pluginAddress,
     * address poolAddress,
     * uint160 sqrtPriceLimitX96)`.
     */
    function decodeUniswapV3PoolData(
        bytes memory data
    ) internal pure returns (address poolAddress, uint160 sqrtPriceLimitX96) {
        require(data.length == 60, "invalid length");

        assembly {
            let location := data

            // skip the 160 bits for plugin address
            let pluginData_1 := mload(add(location, add(0x20, 0x14)))

            poolAddress := shr(96, pluginData_1)

            // skip 320 bits ( 160 (plugin) + 160(pool) )
            let pluginData_2 := mload(add(location, add(0x20, 0x28)))
            sqrtPriceLimitX96 := shr(96, pluginData_2)
        }
    }

    /**
     * @notice Decodes data for Quickswap router.
     * @param data The data to be decoded.
     * @dev The data should be encoded as:
     * `abi.encodePacked(
     * address pluginAddress,
     * uint96 amountOutMin,
     * uint32 deadline)`.
     */
    function decodeQuickswapRouterExactInputSingleData(
        bytes memory data
    ) internal pure returns (uint96 amountOutMin, uint32 deadline) {
        require(
            data.length == QUICKSWAP_ROUTER_EXACT_INPUT_SINGLE_DATA_LENGTH,
            "invalid length"
        );

        assembly {
            let location := data

            // skip the 160 bits for plugin address
            let pluginData_1 := mload(add(location, add(0x20, 0x14)))

            amountOutMin := shr(160, pluginData_1)

            // skip 256 bits ( 160 (plugin) + 96(amountOutMin) )
            let pluginData_2 := mload(add(location, add(0x20, 0x20)))
            deadline := shr(224, pluginData_2)
        }
    }

    /**
     * @notice Decodes data for Quickswap router.
     * @param data The data to be decoded.
     * @dev The data should be encoded as:
     * `abi.encodePacked(
     * address pluginAddress,
     * uint96 amountOutMin,
     * uint32 deadline,
     * bytes memory data)`.
     */
    function decodeQuickswapRouterExactInputData(
        bytes memory data
    )
        internal
        pure
        returns (uint96 amountOutMin, uint32 deadline, address[] memory path)
    {
        // require(data.length == 36, "invalid Length");

        assembly {
            let location := add(data, 0x20)

            // skip the 160 bits for plugin address
            let pluginData_1 := mload(add(location, 0x14))

            amountOutMin := shr(160, pluginData_1)

            // skip 256 bits ( 160 (plugin) + 96(amountOutMin) )
            let pluginData_2 := mload(add(location, 0x20))
            deadline := shr(224, pluginData_2)

            // skip 288 bits (160 (plugin) + 96 (amountOutMin) + 32 (deadline))
            let pathStart := add(location, 0x24)

            // calculate the length of the path array
            let dataLength := mload(data)
            let pathLength := div(sub(dataLength, 0x24), 0x14) // each address is 20 bytes

            // Allocate memory for the path and set its length
            path := mload(0x40)
            mstore(path, pathLength)
            let pathArrayStart := add(path, 0x20)

            // Update the free memory pointer
            mstore(0x40, add(pathArrayStart, mul(pathLength, 0x20))) // each parameter is 32 bytes

            // Copy path elements
            for {
                let i := 0
            } lt(i, pathLength) {
                i := add(i, 1)
            } {
                let element := and(
                    shr(96, mload(add(pathStart, mul(i, 0x14)))),
                    0xffffffffffffffffffffffffffffffffffffffff
                )

                mstore(add(pathArrayStart, mul(i, 0x20)), element)
            }
        }
    }
}
