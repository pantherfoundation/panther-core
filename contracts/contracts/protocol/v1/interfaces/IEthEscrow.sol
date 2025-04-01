// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

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
