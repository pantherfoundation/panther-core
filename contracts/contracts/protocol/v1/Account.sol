// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

/**
 * @title Account
 * @author Pantherprotocol Contributors
 * @dev This smart account contract is ERC-4337 compliant and serves as an interface to interact with a protocol
 * using bundlers as third-party executors for on-chain batch transactions.
 * It essentially functions as a MultiCall, facilitating efficient execution of multiple transactions in a single batch.
 * The authorization ensures the following:
 * Offset Matching: The contract verifies that the offset of the allowed call matches as specified in both
 * the user's operation signature and the payload callData.
 * This ensures that the intended transaction within the batch aligns correctly with the provided callData.
 * Paymaster Compensation Alignment: alidates that the paymaster compensation provided
 * matches across both the payload callData and the operation signature. This synchronization ensures that the paymaster
 * is compensated accurately and consistently for the allowed call.
 */

pragma solidity ^0.8.16;

import "../../common/ImmutableOwnable.sol";
import "./erc4337/contracts/interfaces/IAccount.sol";
import "./erc4337/contracts/interfaces/UserOperation.sol";
import "../../common/NonReentrant.sol";
import "./errMsgs/AccountErrMsgs.sol";
import "../../common/misc/RevertMsgGetter.sol";
import "./account/OffsetGetter.sol";

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
    ) external returns (uint256 validationData) {
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

    function _validateUserOpDataFormat(UserOperation calldata userOp) internal {
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

    function _validateAllowedCallData(UserOperation calldata userOp) internal {
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

    function _requireAllowedCall(address to, bytes memory callData) internal {
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
