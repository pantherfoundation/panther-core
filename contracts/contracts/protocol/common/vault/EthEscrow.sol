// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../interfaces/IEthEscrow.sol";
import "../../../common/PullWithSaltHelper.sol";
import "../../../common/UtilsLib.sol";
import "../errMsgs/EthEscrowErrMsgs.sol";

/**
 * @title EthEscrow
 * @author Pantherprotocol Contributors
 * @notice Handler of ETH users put in escrow for further depositing to MASP
 * @dev IT heavily uses "stealth pull" from `StealthEthPull`.
 */
abstract contract EthEscrow is IEthEscrow {
    using StealthEthPull for bytes32;
    using PullWithSaltHelper for bytes32;

    function sendEthToEscrow(bytes32 salt) external payable override {
        require(msg.value != 0, ERR_ZERO_MSG_VALUE);
        bytes32 escrowSalt = _getEscrowSalt(salt, msg.sender);
        address escrowAddr = escrowSalt.getStealthAddr();

        // Reentrancy impossible as escrowAddr never has a bytecode
        payable(escrowAddr).transfer(msg.value);

        emit DepositedToEscrow(msg.sender, msg.value, salt, escrowAddr);
    }

    function withdrawEthFromEscrow(bytes32 salt) external override {
        bytes32 escrowSalt = _getEscrowSalt(salt, msg.sender);
        address escrowAddr = escrowSalt.getStealthAddr();

        uint256 value = escrowAddr.balance;
        require(value != 0, ERR_ZERO_ETH_BALANCE);

        escrowSalt.pullEthBalanceWithSalt();
        // Reentrancy impossible since only 2300 gas allocated
        payable(msg.sender).transfer(value);

        emit ReturnedFromEscrow(msg.sender, value, salt, escrowAddr);
    }

    function getEscrowAddress(
        bytes32 salt,
        address depositor
    ) public view override returns (address escrowAddr) {
        bytes32 escrowSalt = _getEscrowSalt(salt, depositor);
        escrowAddr = _getEscrowAddress(escrowSalt);
    }

    /// @dev Pull to `address(this)` the ETH `value` from the escrow address defined
    /// by `depositor` and `salt`. The escrow is supposed to be a "stealth" account
    /// holding exactly `value` ETH on its balance.
    function pullEthFromEscrow(
        bytes32 salt,
        address depositor,
        uint256 value
    ) internal {
        bytes32 escrowSalt = _getEscrowSalt(salt, depositor);
        address escrowAddr = escrowSalt.getStealthAddr();
        escrowSalt.pullEthWithSalt(value);

        emit FundedFromEscrow(depositor, value, salt, escrowAddr);
    }

    function _getEscrowSalt(
        bytes32 salt,
        address depositor
    ) private pure returns (bytes32) {
        require(uint256(salt) != 0, ERR_ZERO_SALT);
        require(depositor != address(0), ERR_ZERO_DEPOSITOR_ADDR);
        return keccak256(abi.encode(salt, depositor));
    }

    // Zero input checks omitted as _getEscrowSalt is supposed to have it checked
    function _getEscrowAddress(
        bytes32 escrowSalt
    ) private view returns (address escrowAddr) {
        escrowAddr = address(escrowSalt.getStealthAddr());
    }
}
