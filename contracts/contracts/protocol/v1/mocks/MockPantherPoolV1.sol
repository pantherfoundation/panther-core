// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable one-contract-per-file
pragma solidity ^0.8.19;

contract MockPantherPoolV1 {
    event LogGenerateRewards(
        bytes32 _secretHash,
        uint64 _amount,
        bytes4 _voucherType
    );

    constructor() {}

    function increaseZkpReserve() external {}

    function generateRewards(
        bytes32 _secretHash,
        uint64 _amount,
        bytes4 _voucherType
    ) external {
        emit LogGenerateRewards(_secretHash, _amount, _voucherType);
    }

    function adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
        address token,
        int256 netAmount,
        address extAccount
    ) external payable {}
}
