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
 * Upon verification of paymasterCompensation and requiredPrefund the user operation
 * is sponsored by paymaster.
 */

import "./errMsgs/PayMasterErrMsgs.sol";

import "./core/interfaces/IPrpVoucherController.sol";
import "./interfaces/IPayOff.sol";
import "./interfaces/ICachedNativeZkpTwap.sol";
import "../../common/ImmutableOwnable.sol";
import "../../common/erc4337/contracts/interfaces/IPaymaster.sol";
import "../../common/erc4337/contracts/interfaces/IEntryPoint.sol";
import "../../common/erc4337/contracts/interfaces/UserOperation.sol";
import { GT_PAYMASTER_REFUND, HUNDRED_PERCENT, PROTOCOL_TOKEN_DECIMALS } from "../../common/Constants.sol";

contract PayMaster is ImmutableOwnable, IPaymaster {
    event UserOperationValidated(
        bytes32 userOpHash,
        uint256 requiredPreFund,
        uint256 requiredZkpCompensation,
        uint256 chargedZkpCompensation
    );
    event UserOperationSponsored(bytes32 userOpHash, uint256 actualGasCosts);
    event EntryPointDeposited(uint256 amount);
    event BundlerConfigUpdated(address bundler, BundlerConfig config);
    event VoucherNotGranted(string reason);

    address public immutable PRP_VOUCHER_GRANTOR;
    address public immutable ENTRY_POINT;
    address public immutable ACCOUNT;
    address public immutable FEE_MASTER;

    // Mapping from Bundler address to params
    mapping(address => BundlerConfig) public bundlerConfigs;

    /// @dev Minimum amount of the EntryPoint deposit to get the reward
    uint96 public depositThreshold;

    /// @dev Struct for storing configuration for a bundler.
    /// @param isEnabled True if enabled.
    /// @param maxExtraGas Maximum allowed gas for verification and post-operation;
    /// the bundler may be compensated for at most `userOp.callGasLimit + maxExtraGas`.
    /// @param gasPriceMarkupPct add some gap to current gas price
    /// @param exchangeRiskPct An additional percentage added to the required prefund
    /// to mitigate exchange rate risk.Expressed in units of 0.01% (e.g., 500 means 5%).
    struct BundlerConfig {
        bool isEnabled;
        uint24 maxExtraGas;
        uint16 gasPriceMarkupPct;
        uint32 exchangeRiskPct;
    }

    constructor(
        address _entryPoint,
        address _account,
        address _feeMaster,
        address _prpVoucherGrantor
    ) ImmutableOwnable(msg.sender) {
        _ensureNonZeroAddress(_entryPoint);
        _ensureNonZeroAddress(_account);
        _ensureNonZeroAddress(_feeMaster);
        _ensureNonZeroAddress(_prpVoucherGrantor);

        ENTRY_POINT = _entryPoint;
        ACCOUNT = _account;
        FEE_MASTER = _feeMaster;
        PRP_VOUCHER_GRANTOR = _prpVoucherGrantor;
    }

    receive() external payable {}

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
     * @return context The encoded context containing requiredZkpCompensation and chargedZkpCompensation.
     * @return validationData The validation data (currently returns 0).
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPreFund
    ) external returns (bytes memory context, uint256 validationData) {
        _ensureEntryPointCall();
        _sanitizeUserOp(userOp);

        BundlerConfig memory config = _getCallingBundlerConfig();
        _validateRequiredPrefund(userOp, requiredPreFund, config);

        // Retrieve the cached ZKP price in its native decimal format
        uint256 cachedZKPPrice = ICachedNativeZkpTwap(FEE_MASTER)
            .cachedNativeRateInZkp();

        // Calculate the paymaster compensation in ZKP
        uint256 requiredZkpCompensation = _addExtraPct(
            (requiredPreFund * cachedZKPPrice),
            config.exchangeRiskPct
        ) / PROTOCOL_TOKEN_DECIMALS;

        (, uint256 chargedZkpCompensation) = abi.decode(
            userOp.signature,
            (uint256, uint256)
        );

        require(
            requiredZkpCompensation <= chargedZkpCompensation,
            ERR_SMALL_PAYMASTER_COMPENSATION
        );

        emit UserOperationValidated(
            userOpHash,
            requiredPreFund,
            requiredZkpCompensation,
            chargedZkpCompensation
        );

        context = abi.encode(userOpHash);

        return (context, 0);
    }

    /**
     * @dev Handles post-operation actions after a user operation is completed.
     * This function is called by the EntryPoint contract after a user operation has been executed.
     * It emits event containing sponsored user operation actual gas cost and hash
     * @param mode Post-operation executed mode
     * @param context The context data passed from the pre-operation validation, it contains userOpHash
     * @param actualGasCost The actual gas cost incurred during the user operation.
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external {
        _ensureEntryPointCall();

        if (mode == PostOpMode.opSucceeded) {
            bytes32 userOpHash = abi.decode(context, (bytes32));
            emit UserOperationSponsored(userOpHash, actualGasCost);
        } else {
            revert(ERR_USER_OP_REVERTED);
        }
    }

    /**
     * @dev Claims FeeMaster's debt and sends it to EntryPoint's Paymaster's deposit
     * If refund sum is more than configured, requests a voucher for transaction caller
     * by provided saltHash
     */
    function claimEthAndRefundEntryPoint(bytes32 saltHash) external {
        uint256 claimedAmount = _claimCompensationFromFeeMaster();
        _depositAllBalance();
        if (depositThreshold > 0 && claimedAmount > depositThreshold) {
            _requestRewardsFromPrpVoucherGrantor(saltHash);
        }
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

    /// @notice Configuration parameters setup
    /// @param bundler executor address
    /// @param newConfig config
    function updateBundlerConfig(
        address bundler,
        BundlerConfig memory newConfig
    ) public onlyOwner {
        _ensureNonZeroAddress(bundler);
        /// @dev no limitations on newConfig fields
        bundlerConfigs[bundler] = newConfig;
        emit BundlerConfigUpdated(bundler, newConfig);
    }

    function updateDepositThreshold(
        uint96 _depositThreshold
    ) external onlyOwner {
        require(_depositThreshold > 0, ERR_THRESHOLD_CANT_BE_ZERO);
        depositThreshold = _depositThreshold;
    }

    /**
     * @dev Ensures the required prefund lies within an affordable range.
     * Reference:
     * https://github.com/eth-infinitism/account-abstraction/v0.0.6/contracts/core/EntryPoint.sol#L325
     */
    function _validateRequiredPrefund(
        UserOperation calldata userOp,
        uint256 requiredPreFund,
        BundlerConfig memory config
    ) internal view {
        uint256 toleratedGasPrice = _addExtraPct(
            tx.gasprice + block.basefee,
            config.gasPriceMarkupPct
        );
        uint256 toleratedGas = userOp.callGasLimit + config.maxExtraGas;
        uint256 toleratedGasCosts = toleratedGas * toleratedGasPrice;

        require(
            requiredPreFund <= toleratedGasCosts,
            ERR_LARGE_REQUIRED_PREFUND
        );
    }

    /**
     * @dev Claims the compensation from the FeeMaster contract.
     */
    function _claimCompensationFromFeeMaster() internal returns (uint256) {
        return IPayOff(FEE_MASTER).payOff(address(this));
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

    function _addExtraPct(
        uint256 value,
        uint256 extraPct
    ) internal pure returns (uint256 increasedValue) {
        return value + (value * extraPct) / HUNDRED_PERCENT;
    }

    function _sanitizeUserOp(UserOperation calldata userOp) internal view {
        require(userOp.sender == ACCOUNT, ERR_NOT_TRUSTED_ACCOUNT);
        require(
            userOp.paymasterAndData.length == 20,
            ERR_WRONG_PAYMASTER_AND_DATA
        );
    }

    function _ensureEntryPointCall() internal view {
        require(msg.sender == ENTRY_POINT, ERR_NOT_ALLOWED_CALL);
    }

    function _getCallingBundlerConfig()
        internal
        view
        returns (BundlerConfig memory)
    {
        // solhint-disable-next-line avoid-tx-origin
        return _getBundlerConfig(tx.origin);
    }

    function _getBundlerConfig(
        address bundler
    ) internal view returns (BundlerConfig memory) {
        BundlerConfig memory config = bundlerConfigs[bundler];
        require(config.isEnabled, ERR_BUNDLER_NOT_ENABLED);
        return config;
    }

    function _ensureNonZeroAddress(address _address) internal view {
        require(_address != address(0), ERR_ZERO_ADDRESS);
    }
}
