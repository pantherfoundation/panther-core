// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC20_TOKEN_TYPE, NATIVE_TOKEN_TYPE } from "../../../common/Constants.sol";
import "../../../common/TransferHelper.sol";

library TokenApprovalLib {
    using TransferHelper for address;

    function approveInputAmountOrReturnNativeInputAmount(
        address tokenIn,
        uint8 tokenType,
        address spender,
        uint96 amountIn
    ) internal returns (uint256 nativeInputAmount) {
        if (tokenType == ERC20_TOKEN_TYPE) {
            tokenIn.safeApprove(spender, amountIn);
        }
        if (tokenType == NATIVE_TOKEN_TYPE) {
            nativeInputAmount = amountIn;
        }
    }
}
