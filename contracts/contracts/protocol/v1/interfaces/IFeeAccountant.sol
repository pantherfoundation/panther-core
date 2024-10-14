// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import { FeeData, AssetData, ChargedFeesPerTx } from "../feeMaster/Types.sol";

interface IFeeAccountant {
    /**
     * @notice Accounts fees based on the provided FeeData.
     * @dev This external function processes fee information encapsulated in the `FeeData` struct.
     *      It performs the following operations:
     *      1. **Donation Verification:**
     *         - If `scAddedZkpAmount` is greater than zero, it verifies that the donation amount for the specific
     *           transaction type (`txType`) is correctly configured and that the contract has sufficient donation reserves.
     *         - This verification is enforced by the `checkAvailableDonation` modifier.
     *
     *      2. **Charged ZKP Amount Verification:**
     *         - Ensures that the total charged ZKP amount (`scChargedZkpAmount`) is greater than zero.
     *         - This check is enforced by the `checkChargedZkpAmount` modifier.
     *
     *      3. **Fee Allocation:**
     *         - **Mining Rewards:** Allocates mining rewards to the `pantherTrees` provider based on the number of output UTXOs
     *             and the configured per-UTXO reward.
     *         - **Paymaster Compensation:** If `scPaymasterZkpFee` is greater than zero, it compensates the paymaster by converting
     *             ZKP tokens to native tokens using the `_tryInternalZkpToNativeConversion` function.
     *         - **Donations:** If a donation is included (`scAddedZkpAmount`), it allocates the donation to the user and decreases the
     *             available donation reserve accordingly.
     *
     *      4. **State Updates:**
     *         - Decreases the available donation reserve if a donation is processed.
     *         - Updates the debts for the `trustProvider`, `pantherTrees`, and `paymaster` based on the allocated fees.
     *
     * @param feeData A `FeeData` struct containing the following fields:
     *        - `txType` (uint16): The type identifier of the transaction.
     *        - `numOutputUtxos` (uint8): The number of output UTXOs in the transaction.
     *        - `scPaymasterZkpFee` (uint40): The scaled ZKP fee allocated for paymaster compensation (scaled by 1e12).
     *        - `scAddedZkpAmount` (uint40): The scaled ZKP amount donated by the FeeMaster (scaled by 1e12).
     *        - `scChargedZkpAmount` (uint40): The scaled total ZKP amount charged to the user (scaled by 1e12).
     *
     * @return chargedFeesPerTx A `ChargedFeesPerTx` struct containing the fees that have been charged
     *
     *
     * Requirements:
     * - The caller must be the designated `pantherPoolV1` contract.
     * - If a donation is included (`scAddedZkpAmount > 0`):
     *      - The donation amount must match the configured amount for the transaction type.
     *      - The contract must have sufficient donation reserves to cover the donation.
     * - The total charged ZKP amount (`scChargedZkpAmount`) must be greater than zero.
     * - The function must correctly handle scaling of ZKP amounts by 1e12.
     * - The `updateFeeParams` function must have been called to configure per-UTXO rewards and other fee parameters.
     *
     * Reverts:
     * - Reverts with "invalid donation amount" if the donation amount does not match the configured amount for the transaction type.
     * - Reverts with "not enough donation reserve" if the contract lacks sufficient donation reserves to cover the donation.
     * - Reverts with "zero charged zkp" if the `scChargedZkpAmount` is zero.
     * - Reverts with "insufficient mining rewards" if the charged ZKP amount cannot cover the mining rewards after accounting for
     *   other fees.
     *
     */
    function accountFees(
        FeeData calldata feeData
    ) external returns (ChargedFeesPerTx memory chargedFeesPerTx);

    /**
     * @notice Accounts fees and associated asset data based on the provided FeeData and AssetData.
     * @dev This external function processes fee information encapsulated in the `FeeData` struct
     *      alongside additional asset-related information in the `AssetData` struct.
     *      It performs the following operations:
     *      1. **Donation Verification:**
     *         - If `scAddedZkpAmount` is greater than zero, it verifies that the donation amount for the specific
     *           transaction type (`txType`) is correctly configured and that the contract has sufficient donation reserves.
     *         - This verification is enforced by the `checkAvailableDonation` modifier.
     *
     *      2. **Charged ZKP Amount Verification:**
     *         - Ensures that the total charged ZKP amount (`scChargedZkpAmount`) is greater than zero.
     *         - This check is enforced by the `checkChargedZkpAmount` modifier.
     *
     *      3. **Asset Validation:**
     *         - Validates the provided `assetData` to ensure that all asset-related parameters are correct and meet protocol requirements.
     *         - This may include checking asset balances, allowances, or specific asset attributes.
     *
     *      4. **Fee Allocation:**
     *         - **Mining Rewards:** Allocates mining rewards to the `pantherTrees` provider based on the number of output UTXOs and the
     *             configured per-UTXO reward.
     *         - **Paymaster Compensation:** If `scPaymasterZkpFee` is greater than zero, it compensates the paymaster by converting ZKP
     *             tokens to native tokens using
     *             the `_tryInternalZkpToNativeConversion` function.
     *         - **Donations:** If a donation is included (`scAddedZkpAmount`), it allocates the donation to the user and decreases the
     *             available donation reserve accordingly.
     *         - **Asset Fees:** Allocates additional fees or performs asset-specific operations as defined in the `assetData`.
     *
     *      5. **State Updates:**
     *         - Decreases the available donation reserve if a donation is processed.
     *         - Updates the debts for the `trustProvider`, `pantherTrees`, and `paymaster` based on the allocated fees.
     *         - Updates asset-related state variables based on the `assetData`.
     *
     *
     * @param feeData A `FeeData` struct containing the following fields:
     *        - `txType` (uint16): The type identifier of the transaction.
     *        - `numOutputUtxos` (uint8): The number of output UTXOs in the transaction.
     *        - `scPaymasterZkpFee` (uint40): The scaled ZKP fee allocated for paymaster compensation (scaled by 1e12).
     *        - `scAddedZkpAmount` (uint40): The scaled ZKP amount donated by the FeeMaster (scaled by 1e12).
     *        - `scChargedZkpAmount` (uint40): The scaled total ZKP amount charged to the user (scaled by 1e12).
     *
     * @param assetData An `AssetData` struct containing the following fields:
     *        - `assetType` (uint8): The type identifier of the asset (e.g., ERC20, ERC721).
     *        - `assetAddress` (address): The contract address of the asset.
     *        - `assetAmount` (uint256): The amount of the asset involved in the fee processing.
     *        - `additionalParams` (bytes): Encoded additional parameters relevant to the asset processing.
     *
     * @return chargedFeesPerTx A `ChargedFeesPerTx` struct containing the fees that have been charged
     *
     * - The caller must be the designated `pantherPoolV1` contract.
     * - If a donation is included (`scAddedZkpAmount > 0`):
     *      - The donation amount must match the configured amount for the transaction type.
     *      - The contract must have sufficient donation reserves to cover the donation.
     * - The total charged ZKP amount (`scChargedZkpAmount`) must be greater than zero.
     * - The provided `assetData` must be valid and conform to protocol asset requirements.
     * - The function must correctly handle scaling of ZKP amounts by 1e12.
     * - The `updateFeeParams` function must have been called to configure per-UTXO rewards and other fee parameters.
     *
     *  Note: The assumption is that the token address is either ERC20 or Native token (ie address(0)), the NFT case shall
     *        addressed later.
     **/
    function accountFees(
        FeeData calldata feeData,
        AssetData calldata assetData
    ) external returns (ChargedFeesPerTx memory chargedFeesPerTx);
}
