// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import { FeeData, AssetData, ChargedFeesPerTx } from "../feeMaster/Types.sol";

interface IFeeAccountant {
    /**
     * @dev Accounts for the fees incurred in a transaction.
     * @param feeData Fee data containing transaction type and fee amounts.
     * @return chargedFeesPerTx The charged fees for the transaction.
     */
    function accountFees(
        FeeData calldata feeData
    ) external returns (ChargedFeesPerTx memory chargedFeesPerTx);

    /**
     * @dev Accounts for the fees incurred in a transaction involving assets.
     * @param feeData Fee data containing transaction type and fee amounts.
     * @param assetData Asset data containing information about the assets involved
     * in the transaction.
     * @return chargedFeesPerTx The charged fees for the transaction.
     */
    function accountFees(
        FeeData calldata feeData,
        AssetData calldata assetData
    ) external returns (ChargedFeesPerTx memory chargedFeesPerTx);
}
