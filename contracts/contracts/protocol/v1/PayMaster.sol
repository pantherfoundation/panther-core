// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

/**
 * @title PayMaster
 * @dev The paymaster assumes the role of the sponsor for the Account contract.
 * Through the allocation of deposited and staked funds in the EntryPoint, this contract
 * has the capability to facilitate transaction payments.
 * The paymaster knows in advance the requisite network fee that the user will pay in
 * ZKP tokens and gets the exchange rate from the FeeMaster.
 * Upon verification of sufficient funds, transactions proceed successfully, culminating in
 * the settlement of the user's debt to the paymaster in Ethereum as an integral part of
 * the transaction process.
 */

import "./errMsgs/PayMasterErrMsgs.sol";

import "./core/interfaces/IPrpVoucherController.sol";
import "./interfaces/IPayOff.sol";
import "./interfaces/IProviderFeeDebt.sol";
import "./interfaces/ICachedNativeZkpTwap.sol";
import "../../common/ImmutableOwnable.sol";
import "../../common/erc4337/contracts/interfaces/IPaymaster.sol";
import "../../common/erc4337/contracts/interfaces/IEntryPoint.sol";
import "../../common/erc4337/contracts/interfaces/UserOperation.sol";
import "../../common/misc/RevertMsgGetter.sol";
// solhint-disable-next-line max-line-length
import { GT_PAYMASTER_REFUND, HUNDRED_PERCENT, NATIVE_TOKEN, PROTOCOL_TOKEN_DECIMALS } from "../../common/Constants.sol";

contract PayMaster is ImmutableOwnable, IPaymaster, RevertMsgGetter {
    event UserOperationSponsored(
        uint256 actualGasCost,
        uint256 requiredPrefundInZKP,
        uint256 paymasterCompensation
    );

    event EntryPointDeposited(uint256 refundAmount);
    event VoucherNotGranted(string reason);

    event ValidatePaymasterUserOpRequested(
        uint256 requiredPreFund,
        uint256 requiredPrefundInZKP,
        uint256 maxFeePerGas,
        uint256 paymasterCompensation
    );

    event ConfigUpdated(
        uint16 postOpGasCost,
        uint32 extraPct,
        uint96 depositThreshold
    );

    address public immutable PRP_VOUCHER_GRANTOR;
    address public immutable ENTRY_POINT;
    address public immutable ORPHAN_WALLET;
    address public immutable FEE_MASTER;

    Config public config;

    /// @dev Struct for storing Paymaster configuration
    /// @param postOpGasCost Gas cost of postOp execution
    /// @param extraPct Extra percentage added to requiredPrefund
    /// to minimize exchange risk. 4-digit precision (5% = 50)
    /// @param depositThreshold Minimum amount to deposit to an EntryPoint
    struct Config {
        uint16 postOpGasCost;
        uint32 extraPct;
        uint96 depositThreshold;
    }

    constructor(
        address _entryPoint,
        address _orphanWallet,
        address _feeMaster,
        address _prpVoucherGrantor
    ) ImmutableOwnable(msg.sender) {
        require(
            _entryPoint != address(0) &&
                _orphanWallet != address(0) &&
                _feeMaster != address(0) &&
                _prpVoucherGrantor != address(0),
            ERR_INIT
        );
        ENTRY_POINT = _entryPoint;
        ORPHAN_WALLET = _orphanWallet;
        FEE_MASTER = _feeMaster;
        PRP_VOUCHER_GRANTOR = _prpVoucherGrantor;
    }

    /// @notice Configuration parameters setup
    /// @param postOpGasCost Gas cost of postOp execution
    /// @param extraPct Extra ZKP value added to minimize exchange risk. 4-digit precision.
    /// @param depositThreshold The minimum amount that is efficient to deposit to EntryPoint
    function updateConfig(
        uint16 postOpGasCost,
        uint32 extraPct,
        uint96 depositThreshold
    ) external onlyOwner {
        require(extraPct <= HUNDRED_PERCENT, ERR_WRONG_EXTRA_CHARGE);

        config = Config(postOpGasCost, extraPct, depositThreshold);

        emit ConfigUpdated(postOpGasCost, extraPct, depositThreshold);
    }

    /**
     * @dev Validates a user operation to ensure it can be sponsored by the PayMaster.
     * The main purpose of this function is to determine whether the PayMaster can sponsor
     * the transaction based on the provided user operation data, the required prefund,
     * and the compensation available. This involves:
     * - Verifying the sender of the user operation.
     * - Ensuring the paymaster and data length is correct.
     * - Retrieving the current ZKP price.
     * - Calculating the total required prefund including the extra percentage to mitigate exchange risks.
     * - Decoding the paymaster compensation from the user operation signature.
     * - Ensuring the calculated required prefund in ZKP is less than or equal to the paymaster compensation.
     *
     * @param userOp The user operation data.
     *  userOpHash The hash of the user operation (unused in this implementation).
     * @param requiredPreFund The required prefund amount.
     * @return context The encoded context containing requiredPrefundInZKP and paymasterCompensation.
     * @return validationData The validation data (currently returns 0).
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 requiredPreFund
    ) external returns (bytes memory context, uint256 validationData) {
        require(userOp.sender == ORPHAN_WALLET, ERR_NOT_TRUSTED_ACCOUNT);
        require(
            userOp.paymasterAndData.length == 20,
            ERR_WRONG_PAYMASTER_AND_DATA
        );

        // Retrieve the cached ZKP price in its native decimal format
        uint256 cachedZKPPrice = ICachedNativeZkpTwap(FEE_MASTER)
            .cachedNativeRateInZkp();

        // Calculate the total required prefund with postOpGasCost
        uint256 requiredTotal = requiredPreFund +
            (config.postOpGasCost * userOp.maxFeePerGas);

        // Add an extra percentage of the requiredTotal
        uint256 totalWithExtraPct = addExtraPct(requiredTotal);

        // Calculate requiredPreFund in ZKP accounting in protocol token decimals
        uint256 requiredPrefundInZKP = (cachedZKPPrice * totalWithExtraPct) /
            PROTOCOL_TOKEN_DECIMALS;

        (, uint256 paymasterCompensation) = abi.decode(
            userOp.signature,
            (uint256, uint256)
        );

        emit ValidatePaymasterUserOpRequested(
            requiredPreFund,
            requiredPrefundInZKP,
            userOp.maxFeePerGas,
            paymasterCompensation
        );

        require(
            requiredPrefundInZKP <= paymasterCompensation,
            ERR_WRONG_ZKP_CHARGED_AMOUNT
        );

        bytes memory _context = abi.encode(
            requiredPrefundInZKP,
            paymasterCompensation
        );

        return (_context, 0);
    }

    /**
     * @dev Handles post-operation actions after a user operation is completed.
     * This function is called by the EntryPoint contract after a user operation has been executed.
     * It emits an event to log details about the sponsored user operation, including the actual gas cost,
     * required prefund in ZKP, and the paymaster compensation.
     * @param mode The mode in which the post-operation is executed (not used in this implementation).
     * @param context The context data passed from the pre-operation validation,
     * containing requiredPrefundInZKP and paymasterCompensation.
     * @param actualGasCost The actual gas cost incurred during the user operation.
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external {
        (mode);

        (uint256 requiredPrefundInZKP, uint256 paymasterCompensation) = abi
            .decode(context, (uint256, uint256));

        emit UserOperationSponsored(
            actualGasCost,
            requiredPrefundInZKP,
            paymasterCompensation
        );
    }

    /**
     * @dev Claims FeeMaster's debt and sends it to EntryPoint's Paymaster's deposit
     * If refund sum is more than configured, requests a voucher for transaction caller
     * by provided saltHash
     */
    function claimEthAndRefundEntryPoint(bytes32 saltHash) external {
        uint256 nativeTokensDebt = getFeeMasterNativeTokenDebt();
        _claimCompensationFromFeeMaster();
        _depositAllBalance();
        if (nativeTokensDebt > config.depositThreshold) {
            _requestRewardsFromPrpVoucherGrantor(saltHash);
        }
    }

    /**
     * @dev Claims the compensation from the FeeMaster contract.
     */
    function _claimCompensationFromFeeMaster() internal {
        IPayOff(FEE_MASTER).payOff(address(this));
    }

    /**
     * @dev Deposits the entire balance of this contract to the EntryPoint contract.
     * This is done to ensure that the PayMaster has sufficient funds to sponsor user operations.
     * After depositing, an event is emitted to log the deposited amount.
     */
    function _depositAllBalance() internal {
        IEntryPoint(ENTRY_POINT).depositTo{ value: address(this).balance }(
            address(this)
        );
        emit EntryPointDeposited(address(this).balance);
    }

    /**
     * @dev Add stake for this paymaster.
     * This method can also carry eth value to add to the current stake.
     * @param unstakeDelaySec The unstake delay for this paymaster. Can only be increased.
     */
    function addStake(uint32 unstakeDelaySec) external payable {
        IEntryPoint(ENTRY_POINT).addStake{ value: msg.value }(unstakeDelaySec);
    }

    /**
     * @dev Unlock the stake in order to withdraw it.
     * The paymaster can't serve requests once unlocked, until it calls addStake again
     */
    function unlockStake() external onlyOwner {
        IEntryPoint(ENTRY_POINT).unlockStake();
    }

    /**
     * @dev Withdraw the entire paymaster's stake.
     * Stake must be unlocked first (and then wait for the unstakeDelay to be over)
     * @param withdrawAddress The address to send withdrawn value.
     */
    function withdrawStake(address payable withdrawAddress) external onlyOwner {
        IEntryPoint(ENTRY_POINT).withdrawStake(withdrawAddress);
    }

    /**
     * @dev Deposits funds to make PayMaster active
     * No authorization required
     */
    function depositToEntryPoint() external payable {
        _depositAllBalance();
    }

    /**
     * @dev Generate rewards for refunding deposit
     * @param saltHash Associated with zAccount that will be
     * granted a voucher for refunding PayMaster
     */
    function _requestRewardsFromPrpVoucherGrantor(bytes32 saltHash) internal {
        try
            IPrpVoucherController(PRP_VOUCHER_GRANTOR).generateRewards(
                saltHash,
                0,
                GT_PAYMASTER_REFUND
            )
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            emit VoucherNotGranted(reason);
        }
    }

    /**
     * @dev Withdraw deposit to address
     * Only contract owner can use
     * @param withdrawAddress The address to send withdrawn value.
     * @param withdrawAmount The amount to withdraw.
     */
    function withdrawTo(
        address payable withdrawAddress,
        uint256 withdrawAmount
    ) external onlyOwner {
        IEntryPoint(ENTRY_POINT).withdrawTo(withdrawAddress, withdrawAmount);
    }

    // that will account for both protocol and native tokens FeeMaster debt to PayMaster
    function getFeeMasterNativeTokenDebt() public view returns (uint256) {
        return IProviderFeeDebt(FEE_MASTER).debts(address(this), NATIVE_TOKEN);
    }

    /**
     * @dev Adds an extra percentage to the required total to account for exchange rate fluctuations.
     * This helps to ensure that the required total is sufficient to cover potential changes in exchange rates.
     *
     * @param requiredTotal The initial required total amount.
     * @return The required total amount with the extra percentage added.
     */
    function addExtraPct(uint256 requiredTotal) public view returns (uint256) {
        // Adding an extra percentage of the requiredTotal
        uint256 requiredTotalWithPct = requiredTotal +
            ((requiredTotal * config.extraPct) / HUNDRED_PERCENT);
        return requiredTotalWithPct;
    }

    receive() external payable {}
}
