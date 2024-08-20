// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IPrpConverter {
    function increaseZkpReserve() external;

    function getReserves()
        external
        view
        returns (
            uint256 _prpReserve,
            uint256 _zkpReserve,
            uint32 _blockTimestampLast
        );
}
