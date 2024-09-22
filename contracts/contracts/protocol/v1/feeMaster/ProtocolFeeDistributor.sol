// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../core/interfaces/IPrpConversion.sol";
import "../core/interfaces/IPrpVoucherController.sol";
import "../trees/interfaces/IMinersNetRewardReserves.sol";
import "../../../common/TransferHelper.sol";
import { HUNDRED_PERCENT } from "../../../common/Constants.sol";

abstract contract ProtocolFeeDistributor {
    using TransferHelper for address;

    address public immutable TREASURY;
    address public immutable PANTHER_TREES;
    address public immutable PRP_CONVERTER;

    uint16 internal _treasuryLockPercentage;

    constructor(address treasury, address pantherTrees, address prpConverter) {
        TREASURY = treasury;
        PANTHER_TREES = pantherTrees;
        PRP_CONVERTER = prpConverter;
    }

    function _distributeProtocolZkpFees(
        address zkpToken,
        uint256 amount
    ) internal returns (uint256 minersPremiumRewards) {
        minersPremiumRewards = _tryBalanceMinersPremiumRewards(amount);

        uint256 remainingZkps = amount - minersPremiumRewards;

        if (remainingZkps > 0) {
            _sendZkpsToPrpConverterAndTreasury(zkpToken, remainingZkps);
        }
    }

    function _tryBalanceMinersPremiumRewards(
        uint256 availableAmount
    ) private returns (uint256 usedZkps) {
        int256 netRewardReserve = IMinersNetRewardReserves(PANTHER_TREES)
            .netRewardReserve();

        if (netRewardReserve < 0) {
            usedZkps = availableAmount > uint256(-netRewardReserve)
                ? uint256(-netRewardReserve)
                : availableAmount;

            IMinersNetRewardReserves(PANTHER_TREES).allocateRewardReserve(
                uint112(usedZkps)
            );
        }
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
        IPrpConversion(PRP_CONVERTER).increaseZkpReserve();
    }
}
