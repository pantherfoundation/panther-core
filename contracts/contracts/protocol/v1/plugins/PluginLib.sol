// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
// solhint-disable no-inline-assembly
pragma solidity ^0.8.19;

library PluginLib {
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
    function decodeUniswapRouterData(
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
}
