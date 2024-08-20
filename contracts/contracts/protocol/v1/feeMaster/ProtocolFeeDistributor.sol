// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../interfaces/IPrpConverter.sol";
import "../interfaces/IPrpVoucherGrantor.sol";
import "../../../common/TransferHelper.sol";
import { HUNDRED_PERCENT } from "../../../common/Constants.sol";

abstract contract ProtocolFeeDistributor {
    using TransferHelper for address;

    address public immutable TREASURY;
    address public immutable PRP_CONVERTER;

    uint16 internal _treasuryLockPercentage;

    constructor(address treasury, address prpConverter) {
        TREASURY = treasury;
        PRP_CONVERTER = prpConverter;
    }

    function _distributeProtocolZkpFees(
        address zkpToken,
        uint256 amount
    ) internal returns (uint256 minersPremiumRewards) {
        minersPremiumRewards = _tryBalanceMinersPremiumRewards(
            zkpToken,
            amount
        );

        uint256 remainingZkps = amount - minersPremiumRewards;

        if (remainingZkps > 0) {
            _sendZkpsToPrpConverterAndTreasury(zkpToken, remainingZkps);
        }
    }

    function _tryBalanceMinersPremiumRewards(
        address zkpToken,
        uint256 availableAmount
    )
        private
        returns (uint256 usedZkps)
    // solhint-disable-next-line no-empty-blocks
    {
        // if premium rewards is negative, set it as 0 (plus)
        // zkpToken.safeTransfer(PRP_CONVERTER, usedZkps);
    }

    function _sendZkpsToPrpConverterAndTreasury(
        address zkpToken,
        uint256 availableZkps
    ) private {
        uint256 treasuryAmount = (availableZkps * _treasuryLockPercentage) /
            HUNDRED_PERCENT;
        zkpToken.safeTransfer(TREASURY, treasuryAmount);

        uint256 remainingZkps = availableZkps - treasuryAmount;
        zkpToken.safeTransfer(PRP_CONVERTER, remainingZkps);
        IPrpConverter(PRP_CONVERTER).increaseZkpReserve();
    }
}
