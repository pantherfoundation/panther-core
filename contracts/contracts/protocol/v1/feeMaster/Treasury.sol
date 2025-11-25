// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import "../../../common/NonReentrant.sol";
import "../../../common/Claimable.sol";
import "../../../common/TransferHelper.sol";

/// @title Treasury
/// @notice Holds ZKP protocol fees and releases them on claimer request.
/// @dev Deploy behind a proxy and call {initialize}.
contract Treasury is NonReentrant, Claimable {
    using TransferHelper for address;

    /// @notice Address that is allowed to claim funds
    address public claimer;

    /// @notice Governance address allowed to manage the claimer.
    address public immutable OWNER;

    /// @notice ZKP token used when collecting rewards from FeeMaster.
    address public immutable ZKP_TOKEN;

    bool private initialized;

    event ClaimerUpdated(address indexed newClaimer);
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
        require(msg.sender == claimer, "Treasury: not claimer");
        _;
    }

    modifier whenInitialized() {
        require(initialized, "Treasury: not initialized");
        _;
    }

    constructor(address owner_, address zkpToken_) {
        require(owner_ != address(0), "Treasury: owner zero");
        require(zkpToken_ != address(0), "Treasury: token zero");

        OWNER = owner_;
        ZKP_TOKEN = zkpToken_;
    }

    /// @notice Initializes storage when the contract is deployed behind a proxy.
    function initialize(address claimer_) external onlyOwner {
        require(claimer_ != address(0), "Treasury: claimer zero");
        require(!initialized, "Treasury: already initialized");

        claimer = claimer_;
        initialized = true;
    }

    /**
     * @notice Updates the EOA that is allowed to claim the accumulated rewards.
     * @param newClaimer Address of the new claimer.
     */
    function updateClaimer(address newClaimer) external onlyOwner {
        require(newClaimer != address(0), "Treasury: claimer zero");
        claimer = newClaimer;

        emit ClaimerUpdated(newClaimer);
    }

    /// @notice Allows the owner to rescue tokens other than ZKP.
    function claimOtherErc20(
        address token,
        address to,
        uint256 amount
    ) external whenInitialized onlyOwner nonReentrant {
        require(token != ZKP_TOKEN, "Treasury: reserved");
        require(to != address(0), "Treasury: zero recipient");
        _claimErc20(token, to, amount);
    }

    function claim(
        address receiver,
        uint256 amount
    ) external whenInitialized onlyClaimer nonReentrant {
        require(receiver != address(0), "Treasury: receiver zero");

        ZKP_TOKEN.safeTransfer(receiver, amount);
        emit ClaimExecuted(claimer, receiver, amount);
    }
}
