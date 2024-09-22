// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface IMinersNetRewardReserves {
    function netRewardReserve() external returns (int112);

    function allocateRewardReserve(uint112 allocated) external;
}
