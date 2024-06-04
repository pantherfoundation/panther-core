// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library ScaleHandler {
    // Function to scale a value by a factor and return the scaled value
    function getScaled(
        uint256 value,
        uint256 scaleFactor
    ) internal pure returns (uint256) {
        require(scaleFactor != 0, "ERR_ZERO_SCALE");

        require(value >= scaleFactor, "ERR_LESS_THEN_SCALE");

        return (value / scaleFactor) * scaleFactor;
    }
}
