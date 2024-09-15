// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity 0.8.19;

import "../../publicSignals/PrpAccountingPublicSignals.sol";
import "../../errMsgs/PrpVoucherController.sol";

import "../../../../..//common/UtilsLib.sol";
import { MAX_PRP_AMOUNT } from "../../../../../common/Constants.sol";

abstract contract PrpVoucherHandler {
    using UtilsLib for address;

    // solhint-disable-next-line
    uint64 private ZERO_VALUE = 1;

    /// @dev Struct for storing voucher terms.
    /// @param rewardsGranted The total amount (accumulator) of rewards granted
    /// for this voucher
    /// @param limit The rewards limit of the reward voucher. rewardsGranted <=
    //limit
    /// @param amount The amount of the reward that voucher generates.
    /// @param enabled The status of the voucher terms.
    struct VoucherTerms {
        uint64 rewardsGranted;
        uint64 limit;
        uint64 amount;
        bool enabled;
        // rest of the storage slot (uint120) are available for upgrades
        uint56 _reserved;
    }

    mapping(bytes32 => uint256) public balance;
    mapping(address => mapping(bytes4 => VoucherTerms)) public voucherTerms;

    function _generateRewards(
        bytes32 _secretHash,
        uint64 _amount,
        bytes4 _voucherType
    ) internal returns (uint256) {
        VoucherTerms memory voucherTerm = voucherTerms[msg.sender][
            _voucherType
        ];

        // If amount in the voucher is not set, then the amount is specified
        // by the calling smart contract, otherwise it is specified by the
        uint64 prpToGrant = _amount > 0 ? _amount : voucherTerm.amount;

        if (voucherTerm.rewardsGranted + prpToGrant > voucherTerm.limit)
            return 0;

        // we are setting the balance to non-zero to save gas
        if (balance[_secretHash] > ZERO_VALUE) {
            balance[_secretHash] += prpToGrant;
        } else {
            balance[_secretHash] = ZERO_VALUE + prpToGrant;
        }

        voucherTerms[msg.sender][_voucherType].rewardsGranted += prpToGrant;

        return prpToGrant;
    }

    function _claimRewards(
        uint256[] calldata inputs
    ) internal returns (bytes32 secretHash) {
        secretHash = bytes32(inputs[PRP_ACCOUNTING_SALT_HASH_IND]);

        uint256 rewardAmount = balance[secretHash];

        require(
            rewardAmount > ZERO_VALUE,
            "PrpVoucherGrantor: No reward to claim"
        );

        {
            uint256 withdrawAmountPrp = inputs[
                PRP_ACCOUNTING_WITHDRAW_PRP_AMOUNT_IND
            ];
            require(
                withdrawAmountPrp == 0,
                "PrpVoucherGrantor: Non zero withdraw amount prp"
            );
        }

        {
            uint256 depositAmountPrp = inputs[
                PRP_ACCOUNTING_DEPOSIT_PRP_AMOUNT_IND
            ];
            require(
                depositAmountPrp <= MAX_PRP_AMOUNT,
                "PrpVoucherGrantor: Too large prp amount"
            );
            require(
                rewardAmount == depositAmountPrp,
                "PrpVoucherGrantor: Incorrect reward balance"
            );
        }

        balance[secretHash] = ZERO_VALUE;
    }

    function _updateVoucherTerms(
        address _allowedContract,
        bytes4 _voucherType,
        uint64 _limit,
        uint64 _amount,
        bool _enabled
    ) internal {
        _allowedContract.revertZeroAddress();

        uint64 rewardsGenerated = voucherTerms[_allowedContract][_voucherType]
            .rewardsGranted;

        require(
            _limit + _amount >= rewardsGenerated,
            "PrpVoucherGrantor: Limit cannot be less than rewards generated"
        );

        voucherTerms[_allowedContract][_voucherType] = VoucherTerms(
            rewardsGenerated,
            _limit,
            _amount,
            _enabled,
            uint56(0) // reserved
        );
    }
}
