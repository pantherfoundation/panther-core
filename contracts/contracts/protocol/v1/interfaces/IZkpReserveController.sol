// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IZkpReserveController {
    function getRewardStats()
        external
        view
        returns (
            uint256 _releasablePerBlock,
            uint256 _minRewardableAmount,
            uint256 _totalReleased,
            uint256 _blockAtLastUpdate,
            uint256 _scAccumulatedAccrual
        );

    function releasableAmount() external view returns (uint256);
}
