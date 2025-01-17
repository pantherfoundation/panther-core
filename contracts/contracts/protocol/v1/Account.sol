// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

/**
 * @title Account
 * @dev This contract is a singleton and ERC-4337 compliant, designed to interact with bundlers as third-party
 * executors for on-chain batch transactions. It operates without a proxy and is deployed once per protocol version,
 * shared by all users.
 *
 * Main Features:
 *
 * 1. MultiCall Execution: The contract enables efficient execution of multiple transactions in a single batch,
 *    validating and processing them according to predefined rules.
 *
 * 2. Offset Matching: The contract ensures that the offset of the paymaster compensation in the calldata matches the
 *    predefined value. This is checked against both the user’s operation signature and the calldata. The "offset"
 *    refers to the position in the calldata where the paymasterCompensation value is located.
 *
 * 3. Paymaster Compensation Alignment: The contract validates that the paymaster compensation value is consistent
 *    between the user’s operation signature and the calldata, ensuring correct compensation for the paymaster.
 *
 * 4. Singleton Architecture: Only one instance of the contract is deployed per protocol version, used by all users.
 *    Allowed calls (target address, function selector, and paymaster compensation) are registered during deployment.
 *    At execution, the contract checks if the call's address-function selector-offset combination is registered before
 *    passing the transaction to the paymaster.
 *
 * The contract does not use a proxy mechanism.
 */

pragma solidity ^0.8.16;

import "./account/OffsetGetter.sol";
import "./errMsgs/AccountErrMsgs.sol";

import "../../common/ImmutableOwnable.sol";

import "../../common/erc4337/contracts/interfaces/IAccount.sol";
import "../../common/erc4337/contracts/interfaces/UserOperation.sol";
import "../../common/NonReentrant.sol";
import "../../common/misc/RevertMsgGetter.sol";

contract Account is OffsetGetter, RevertMsgGetter, NonReentrant {
    event AccountBatchExecuted();
    event AccountCallExecuted();

    constructor(
        address[8] memory targets,
        bytes4[8] memory selectors,
        uint32[8] memory offsets
    ) OffsetGetter(targets, selectors, offsets) {}

    /// @dev validateUserOp validate UserOperation
    /// check that amount from signature is not less then provided by bundler
    /// pass call to Paymaster to proceed
    /// @param userOperation UerOperation desired to be executed
    function validateUserOp(
        UserOperation calldata userOperation,
        bytes32,
        uint256
    ) external view returns (uint256 validationData) {
        _validateUserOpDataFormat(userOperation);
        _validateAllowedCallData(userOperation);
        return 0;
    }

    function execute(address to, bytes calldata callData) external {
        require(to.code.length > 0, ERR_NO_CONTRACT);
        require(getOffset(to, bytes4(callData)) > 0, ERR_CALl_FORBIDDEN);
        (bool success, bytes memory result) = to.call{ value: 0 }(callData);
        if (!success) {
            revert(getRevertMsg(result));
        }
        emit AccountCallExecuted();
    }

    /// @dev executes the batch of transactions
    /// that contain at least one allowed ( allowed ) transaction
    /// @param targets - the array of destinations
    /// @param calls - an array of calls containing transactions to be executed on specified destinations.

    function executeBatchOrRevert(
        address[] calldata targets,
        bytes[] memory calls
    ) external nonReentrant {
        require(targets.length == calls.length, "arrays length mismatch");
        if (targets.length == 1) {
            this.execute(targets[0], calls[0]);
        } else {
            bool hasAllowedCall;
            for (uint256 i = 0; i < targets.length; i++) {
                address target = targets[i];
                bytes memory call = calls[i];
                /// check if the array contains allowed calls at the execution stage
                require(target.code.length > 0, ERR_NO_CONTRACT);
                require(call.length > 0, "Call data is empty");
                (bool success, bytes memory result) = target.call{ value: 0 }(
                    call
                );
                if (!success) {
                    revert(getRevertMsg(result));
                }
                bytes4 sigHash = bytes4(call);
                uint32 offSet = getOffset(target, sigHash);
                if (!hasAllowedCall) {
                    hasAllowedCall = isIncluded(target, sigHash, offSet);
                }
            }

            require(hasAllowedCall, ERR_BATCH_FORBIDDEN_ATTEMPT);
            emit AccountBatchExecuted();
        }
    }

    function _validateUserOpDataFormat(
        UserOperation calldata userOp
    ) internal view {
        /// only Account smart contract can be a sender
        require(userOp.sender == address(this), ERR_NOT_SELF);

        /// check the signature length
        /// concatenated allowedCallDataIndex and paymasterCompensation
        require(userOp.signature.length == 64, ERR_WRONG_SIG_LENTGH);

        /// new wallets are not to be deployed, so the initCode should be empty
        require(userOp.initCode.length == 0, ERR_INIT_CODE);

        bytes4 selector = bytes4(userOp.callData[:4]);
        require(
            selector == this.executeBatchOrRevert.selector ||
                selector == this.execute.selector,
            ERR_NOT_ALLOWED_METHOD
        );
    }

    /// @dev validates the userOperation for:
    ///  UserOp.signature is properly constructed
    /// allowedCallData stays o a right place in a batch
    /// allowedCallData is registered
    /// paymasterCompensation in  signature and callData must match
    /// @param userOp UserOperation to be executed throgh

    function _validateAllowedCallData(
        UserOperation calldata userOp
    ) internal view {
        (address[] memory destinations, bytes[] memory calls) = abi.decode(
            userOp.callData[4:],
            (address[], bytes[])
        );

        ///  allowedCallDataIndex - the position of the allowed callData in a batch
        ///  paymasterCompensation - the guaranteed amount the paymaster will be refunded by the protocol
        ///  UserOp.signature - a concatenation of the allowedCallDataIndex and paymasterCompensation

        (uint256 allowedCallDataIndex, uint256 paymasterCompensation) = abi
            .decode(userOp.signature, (uint256, uint256));

        bytes memory allowedCallData = calls[allowedCallDataIndex];

        /// get paymasterCompensationOffset for registered callData
        uint256 paymasterCompensationOffset = getOffset(
            destinations[allowedCallDataIndex],
            bytes4(allowedCallData)
        );

        // paymasterCompensationOffset 0 means that callData is not registered
        require(paymasterCompensationOffset > 0, ERR_NOT_SPONSORED_CALL);

        /// check that paymasterCompensation from the signature and callData match
        _matchPaymasterCompensation(
            allowedCallData,
            paymasterCompensation,
            paymasterCompensationOffset
        );
    }

    /// @dev validate that the desired call is listed
    /// @param to destination contract address
    /// @param callData allowed call callData

    function _requireAllowedCall(
        address to,
        bytes memory callData
    ) internal view {
        require(getOffset(to, bytes4(callData)) > 0, ERR_NOT_SPONSORED_CALL);
    }

    /// @dev validate that paymaster compensation in signature
    /// is the same that passed to allowed call parameter
    /// @param callData allowed call callData bytes
    /// @param paymasterCompensationFromSignature paymaster compensation exttracted from signature
    /// @param paymasterCompensationOffset the offset to extract value from callData

    function _matchPaymasterCompensation(
        bytes memory callData,
        uint256 paymasterCompensationFromSignature,
        uint256 paymasterCompensationOffset
    ) internal pure {
        uint256 amountFromData = _exctractBytesByOffset(
            callData,
            paymasterCompensationOffset
        );
        require(
            paymasterCompensationFromSignature == amountFromData,
            ERR_INEFFICIENT_PAYMASTER_COMPENSATION
        );
    }
}
