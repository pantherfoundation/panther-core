// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../../common/TransferHelper.sol";

contract TestnetZkpAndLinkDonatory {
    address public immutable PANTHER_POOL;
    address public immutable LINK;
    address public immutable ZKP;

    address public immutable OWNER;

    uint256 public linkDonationAmount;
    uint256 public zkpDonationAmount;

    constructor(
        address _owner,
        address pantherPool,
        address link,
        address zkp
    ) {
        OWNER = _owner;

        PANTHER_POOL = pantherPool;
        LINK = link;
        ZKP = zkp;
    }

    function updateLinkDonation(uint256 amount) external {
        require(msg.sender == OWNER, "unauthorize");
        linkDonationAmount = amount;
    }

    function updateZkpDonation(uint256 amount) external {
        require(msg.sender == OWNER, "unauthorize");
        zkpDonationAmount = amount;
    }

    function donateTokens(address user) external {
        require(msg.sender == PANTHER_POOL, "unauthorize");
        if (
            TransferHelper.safeBalanceOf(LINK, address(this)) >
            linkDonationAmount
        ) {
            TransferHelper.safeTransfer(LINK, user, linkDonationAmount);
        }

        if (
            TransferHelper.safeBalanceOf(ZKP, address(this)) > zkpDonationAmount
        ) {
            TransferHelper.safeTransfer(ZKP, user, zkpDonationAmount);
        }
    }

    function rescueTokens(address token, uint256 amount) external {
        require(msg.sender == OWNER, "unauthorize");
        TransferHelper.safeTransfer(token, OWNER, amount);
    }
}
