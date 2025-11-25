// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./interfaces/IDebtSettlement.sol";

/**
 * @title ComplianceTreasury
 * @notice Lightweight upgradeable contract that holds the trust provider role for FeeMaster.
 * @dev Deploy behind a proxy and configure the trust provider EOA through `updateTrustProvider`.
 * The owner address and ZKP token are immutable.
 */
contract ComplianceTreasury {
    /// @notice Address that is allowed to pull rewards from the FeeMaster. Stored in slot 0.
    address public trustProvider;

    /// @notice Governance address allowed to manage the trust provider.
    address public immutable OWNER;

    /// @notice ZKP token used when collecting rewards from FeeMaster.
    address public immutable ZKP_TOKEN;

    event TrustProviderUpdated(address indexed trustProvider);
    event FeesClaimed(
        address indexed feeMaster,
        address indexed receiver,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == OWNER, "ComplianceTreasury: unauthorized");
        _;
    }

    modifier onlyTrustProvider() {
        require(
            msg.sender == trustProvider,
            "ComplianceTreasury: not provider"
        );
        _;
    }

    constructor(address owner_, address zkpToken_) {
        require(owner_ != address(0), "ComplianceTreasury: owner zero");
        require(zkpToken_ != address(0), "ComplianceTreasury: token zero");

        OWNER = owner_;
        ZKP_TOKEN = zkpToken_;
    }

    /**
     * @notice Updates the EOA that is allowed to claim the accumulated rewards.
     * @param newTrustProvider Address of the new trust provider.
     */
    function updateTrustProvider(address newTrustProvider) external onlyOwner {
        require(
            newTrustProvider != address(0),
            "ComplianceTreasury: provider zero"
        );
        trustProvider = newTrustProvider;

        emit TrustProviderUpdated(newTrustProvider);
    }

    /**
     * @notice Claims accrued rewards from FeeMaster in ZKP token to the receiver.
     * @param feeMaster Address of the FeeMaster contract.
     * @param receiver Address receiving the withdrawn rewards.
     * @param amount Amount of ZKP rewards to withdraw.
     */
    function claim(
        address feeMaster,
        address receiver,
        uint256 amount
    ) external onlyTrustProvider returns (uint256 debtPaid) {
        require(feeMaster != address(0), "ComplianceTreasury: feeMaster zero");
        require(receiver != address(0), "ComplianceTreasury: receiver zero");

        debtPaid = IDebtSettlement(feeMaster).payOff(
            ZKP_TOKEN,
            receiver,
            amount
        );

        emit FeesClaimed(feeMaster, receiver, amount);
    }
}
