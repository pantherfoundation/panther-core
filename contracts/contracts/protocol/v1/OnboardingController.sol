// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./interfaces/IPrpVoucherGrantor.sol";

import { ZACCOUNT_STATUS } from "./zAccountsRegistry/Constants.sol";

import "../../common/ImmutableOwnable.sol";
import "../../common/TransferHelper.sol";
import { GT_ONBOARDING } from "../../common/Constants.sol";

contract OnboardingController is ImmutableOwnable {
    using TransferHelper for address;

    uint256 private constant ZERO_REWARD = 0;

    address public immutable ZACCOUNT_REGISTRY;
    address public immutable PRP_VOUCHER_GRANTOR;
    address public immutable ZKP_TOKEN;
    address public immutable VAULT;

    struct RewardParams {
        // kyc provider reward amount in zkp
        uint96 zkpAmount;
        // user reward amount in zZkp
        uint96 zZkpAmount;
        // reserved bytes
        uint64 _unused;
    }

    RewardParams public rewardParams;

    uint128 public rewardsGranted;
    uint128 public rewardsLimit;

    event RewardParamsUpdated(uint96 zkpAmountScaled, uint96 zZkpAmountScaled);
    event RewardsLimtUpdated(uint256 rewardsLimit);
    event ReserveControllerApproved(uint256 amount);
    event ZzkpAndPrpAllocated(
        address user,
        uint256 zZkpAmount,
        uint256 prpAmount
    );

    constructor(
        address _owner,
        address _zkpToken,
        address _zAccountRegistry,
        address _prpVoucherGrantor,
        address _vault
    ) ImmutableOwnable(_owner) {
        require(
            _zAccountRegistry != address(0) &&
                _zkpToken != address(0) &&
                _vault != address(0),
            "init: zero address"
        );

        ZACCOUNT_REGISTRY = _zAccountRegistry;
        PRP_VOUCHER_GRANTOR = _prpVoucherGrantor;
        ZKP_TOKEN = _zkpToken;
        VAULT = _vault;
    }

    function updateRewardParams(
        uint96 _zkpAmount,
        uint96 _zZkpAmount
    ) external onlyOwner {
        // TODO: Should reward amounts be more than 0?

        rewardParams = RewardParams({
            zkpAmount: _zkpAmount,
            zZkpAmount: _zZkpAmount,
            _unused: uint64(0)
        });

        emit RewardParamsUpdated(_zkpAmount, _zZkpAmount);
    }

    function updateRewardsLimitAndVaultAllowance() external {
        // // Getting the current allowance of ReserveController
        // uint256 reserveControllerAllowance = ZKP_TOKEN.safeAllowance(
        //     address(this),
        //     RESERVE_CONTROLLER
        // );
        uint256 _rewardsLimit = rewardsLimit;

        // Getting the unused rewards limit
        uint256 unusedLimit = _rewardsLimit - rewardsGranted;

        // The availabe balance (part of the balance is reserved and will be withdrawn from ReserveController)
        uint256 available = ZKP_TOKEN.safeBalanceOf(address(this));

        // uint256 available = ZKP_TOKEN.safeBalanceOf(address(this)) -
        //     reserveControllerAllowance;

        if (available == unusedLimit) return;

        if (available > unusedLimit) {
            uint256 newAllocation = available - unusedLimit;

            _rewardsLimit += uint128(newAllocation);

            // Approve the vault to transfer its zZkp portion
            ZKP_TOKEN.safeIncreaseAllowance(VAULT, newAllocation);
        } else {
            // gracefully handle this unexpected situation
            uint256 shortage = unusedLimit - available;

            _rewardsLimit = _rewardsLimit > shortage
                ? _rewardsLimit - shortage
                : 0;
        }

        rewardsLimit = uint128(_rewardsLimit);

        emit RewardsLimtUpdated(_rewardsLimit);
    }

    // TODO: review/update OnboardingController.grantRewards
    // solhint-disable no-unused-vars
    function grantRewards(
        address _user,
        uint8 _prevStatus,
        uint8 _newStatus,
        bytes memory _data
    ) external returns (uint256 _zZkpRewardAlloc) {
        require(msg.sender == ZACCOUNT_REGISTRY, "unauthorized");
        require(_data.length == 32, "OC: invalid data length");

        RewardParams memory _rewardParams = rewardParams;

        uint256 _zZkpToAllocate = _prevStatus ==
            uint8(ZACCOUNT_STATUS.REGISTERED)
            ? _rewardParams.zZkpAmount
            : ZERO_REWARD;

        uint256 _newRewardsGranted = rewardsGranted +
            (_rewardParams.zkpAmount + _zZkpToAllocate);

        // return 0 if limit is reached
        if (rewardsLimit < _newRewardsGranted) return _zZkpRewardAlloc;

        if (
            _prevStatus == uint8(ZACCOUNT_STATUS.REGISTERED) &&
            _newStatus == uint8(ZACCOUNT_STATUS.ACTIVATED)
        ) {
            bytes32 secret;

            // solhint-disable no-inline-assembly
            assembly {
                // the 1st word (32 bytes) contains the `message.length`
                // we need the (entire) 2nd word ..
                secret := mload(add(_data, 0x20))
            }
            // solhint-enable no-inline-assembly

            uint256 _prpRewardsGranted = _grantPrpRewardsToUser(secret);

            _zZkpRewardAlloc = _zZkpToAllocate;

            emit ZzkpAndPrpAllocated(
                _user,
                _zZkpRewardAlloc,
                _prpRewardsGranted
            );
        }

        rewardsGranted = uint128(_newRewardsGranted);
    }

    function _grantPrpRewardsToUser(
        bytes32 secretHash
    ) private returns (uint256 _prpRewards) {
        _prpRewards = IPrpVoucherGrantor(PRP_VOUCHER_GRANTOR).generateRewards(
            secretHash,
            0, // amount defined for `GT_ONBOARDING` type will be used
            GT_ONBOARDING
        );
    }
}
