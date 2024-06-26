// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
// solhint-disable no-inline-assembly
pragma solidity ^0.8.19;

library PluginLib {
    // getting the plugin address that is always the first 160 bits
    function extractPluginAddress(
        bytes memory data
    ) internal pure returns (address plugin) {
        require(data.length >= 20, "low length");

        assembly {
            let location := data

            let _data := mload(add(location, 0x20))
            plugin := shr(96, _data)
        }
    }

    /**
     * The data should be encoded like this:
     * abi.encodePacked(
     *  address pluginAddress,
     *  uint32 deadline,
     *  uint96 amountOutMinimum,
     *  uint24 fee,
     *  uint160 sqrtPriceLimitX96)
     */
    function decodeUniswapV3RouterData(
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
        require(data.length == 59, "invalid length");

        assembly {
            let location := data

            // skip the 160 bits for plugin address
            let pluginData_1 := mload(add(location, add(0x20, 0x14)))

            deadline := shr(224, pluginData_1)
            amountOutMinimum := and(
                shr(128, pluginData_1),
                0xffffffffffffffffffffffff
            )
            fee := and(shr(104, pluginData_1), 0xffffffff)

            // skip 312 bits ( 160 (plugin) + 32(deadline) + 96(amountOutMinimum) + 24(fee) )
            let pluginData_2 := mload(add(location, add(0x20, 0x27)))
            sqrtPriceLimitX96 := and(
                0xffffffffffffffffffffffffffffffffffffffff,
                shr(96, pluginData_2)
            )
        }
    }

    /**
     * The data should be encoded like this:
     * abi.encodePacked(
     *  address pluginAddress,
     *  address poolAddress,
     *  uint160 sqrtPriceLimitX96)
     */
    function decodeUniswapV3PoolData(
        bytes memory data
    ) internal pure returns (address poolAddress, uint160 sqrtPriceLimitX96) {
        require(data.length == 60, "invalid Length");

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
     * The data should be encoded like this:
     * abi.encodePacked(
     *  address pluginAddress
     *  uint96 amountOutMin,
     *  uint32 deadline)
     */
    function decodeQuickswapRouterData(
        bytes memory data
    ) internal pure returns (uint96 amountOutMin, uint32 deadline) {
        require(data.length == 36, "invalid Length");

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
}
