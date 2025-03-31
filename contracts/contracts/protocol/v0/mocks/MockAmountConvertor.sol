// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.16;

import "../pantherPool/AmountConvertor.sol";

contract MockAmountConvertor is AmountConvertor {
    function internalScaleAmount(
        uint256 amount,
        uint8 scale
    ) external pure returns (uint96 scaledAmount, uint256 change) {
        return _scaleAmount(amount, scale);
    }

    function internalUnscaleAmount(
        uint64 scaledAmount,
        uint8 scale
    ) external pure returns (uint96) {
        return _unscaleAmount(scaledAmount, scale);
    }
}
