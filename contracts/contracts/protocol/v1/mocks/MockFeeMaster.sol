// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../FeeMaster.sol";

contract MockFeeMaster is FeeMaster {
    using TransferHelper for address;

    constructor(
        address owner,
        Providers memory providers,
        address zkpToken,
        address wethToken,
        address vault,
        address treasury
    ) FeeMaster(owner, providers, zkpToken, wethToken, vault, treasury) {}

    function internalUpdateDebtForProtocol(
        address token,
        int256 netAmount
    ) external {
        _updateDebtForProtocol(token, netAmount);
    }

    function internalTryInternalZkpToNativeConversion(
        uint256 paymasterCompensationInZkp
    ) external {
        _tryInternalZkpToNativeConversion(paymasterCompensationInZkp);
    }

    function internalAccountDebtForPaymaster(
        uint256 paymasterCompensationInZkp
    ) external {
        _accountDebtForPaymaster(paymasterCompensationInZkp);
    }

    function withdrawToken(address token, uint256 amount) external {
        token.safeTransfer(OWNER, amount);
    }

    receive() external payable override {}
}
