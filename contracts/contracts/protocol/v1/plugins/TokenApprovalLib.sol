// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../core/libraries/TokenTypeAndAddressDecoder.sol";

import { ERC20_TOKEN_TYPE, NATIVE_TOKEN_TYPE } from "./../../../common/Constants.sol";
import "./../../../common/TransferHelper.sol";

library TokenApprovalLib {
    using TransferHelper for address;
    using TokenTypeAndAddressDecoder for uint168;

    function approveInputAmountOrReturnNativeInputAmount(
        address tokenInAddress,
        uint8 tokenInType,
        address spender,
        uint96 amountIn
    ) internal returns (uint256 nativeInputAmount) {
        if (tokenInType == ERC20_TOKEN_TYPE) {
            tokenInAddress.safeApprove(spender, amountIn);
        }
        if (tokenInType == NATIVE_TOKEN_TYPE) {
            nativeInputAmount = amountIn;
        }
    }
}
