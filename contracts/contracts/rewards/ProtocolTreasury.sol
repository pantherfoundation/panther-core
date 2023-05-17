// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../common/Claimable.sol";
import "../common/ImmutableOwnable.sol";

/**
 * @title ProtocolTreasury
 * @author Pantherprotocol Contributors
 * @notice It receives ERC20/Eth assets. Only owner can calim the collected assets.
 */
contract ProtocolTreasury is ImmutableOwnable, Claimable {
    event Claimed(address claimer, address token, address to, uint256 amount);

    constructor(address _owner) ImmutableOwnable(_owner) {} // solhint-disable-line no-empty-blocks

    function claimEthOrErc20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        _claimEthOrErc20(token, to, amount);

        emit Claimed(msg.sender, token, to, amount);
    }

    receive() external payable {} // solhint-disable-line no-empty-blocks
}
