// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import "../../../common/NonReentrant.sol";
import "../../../common/Claimable.sol";
import "../../../common/TransferHelper.sol";

/// @title Treasury
/// @notice Holds ZKP protocol fees and releases them on claimer request.
/// @dev Deploy behind a proxy with claimer set in constructor.
contract Treasury is NonReentrant, Claimable {
    using TransferHelper for address;

    /// @notice Governance address allowed to manage the claimer.
    address public immutable OWNER;

    /// @notice ZKP token used when collecting rewards from FeeMaster.
    address public immutable ZKP_TOKEN;

    /// @notice Address that is allowed to claim funds.
    address public immutable CLAIMER;

    event ClaimExecuted(
        address indexed claimer,
        address indexed receiver,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == OWNER, "Treasury: unauthorized owner");
        _;
    }

    modifier onlyClaimer() {
        require(msg.sender == CLAIMER, "Treasury: not claimer");
        _;
    }

    constructor(address owner_, address zkpToken_, address claimer_) {
        require(owner_ != address(0), "Treasury: owner zero");
        require(zkpToken_ != address(0), "Treasury: token zero");
        require(claimer_ != address(0), "Treasury: claimer zero");

        OWNER = owner_;
        ZKP_TOKEN = zkpToken_;
        CLAIMER = claimer_;
    }

    /// @notice Allows the owner to rescue tokens other than ZKP.
    function claimOtherErc20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(token != ZKP_TOKEN, "Treasury: reserved");
        require(to != address(0), "Treasury: zero recipient");
        _claimErc20(token, to, amount);
    }

    function claim(
        address receiver,
        uint256 amount
    ) external onlyClaimer nonReentrant {
        require(receiver != address(0), "Treasury: receiver zero");

        ZKP_TOKEN.safeTransfer(receiver, amount);
        emit ClaimExecuted(CLAIMER, receiver, amount);
    }
}
