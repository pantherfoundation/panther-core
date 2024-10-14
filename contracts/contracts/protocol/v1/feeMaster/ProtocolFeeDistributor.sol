// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../core/interfaces/IPrpConversion.sol";
import "../core/interfaces/IPrpVoucherController.sol";
import "../../../common/TransferHelper.sol";
import { HUNDRED_PERCENT } from "../../../common/Constants.sol";

abstract contract ProtocolFeeDistributor {
    using TransferHelper for address;

    address public immutable TREASURY;
    address public immutable PANTHER_TREES;
    address public immutable PRP_CONVERTER;

    uint16 public treasuryLockPercentage;

    constructor(address treasury, address pantherTrees, address prpConverter) {
        TREASURY = treasury;
        PANTHER_TREES = pantherTrees;
        PRP_CONVERTER = prpConverter;
    }

    function _distributeProtocolZkpFees(
        address zkpToken,
        uint256 amount
    ) internal {
        uint256 treasuryAmount = (amount * treasuryLockPercentage) /
            HUNDRED_PERCENT;
        zkpToken.safeTransfer(TREASURY, treasuryAmount);

        uint256 remainingZkps = amount - treasuryAmount;
        zkpToken.safeTransfer(PRP_CONVERTER, remainingZkps);
        IPrpConversion(PRP_CONVERTER).increaseZkpReserve();
    }
}
