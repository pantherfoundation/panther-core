// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

/**
 * @title EthEscrow interface
 * @author Pantherprotocol Contributors
 */
interface IEthEscrow {
    event DepositedToEscrow(
        address depositor,
        uint256 value,
        bytes32 salt,
        address escrow
    );
    event FundedFromEscrow(
        address depositor,
        uint256 value,
        bytes32 salt,
        address escrow
    );
    event ReturnedFromEscrow(
        address depositor,
        uint256 value,
        bytes32 salt,
        address escrow
    );

    function sendEthToEscrow(bytes32 salt) external payable;

    function withdrawEthFromEscrow(bytes32 salt) external;

    function getEscrowAddress(
        bytes32 salt,
        address depositor
    ) external view returns (address escrowAddr);
}
