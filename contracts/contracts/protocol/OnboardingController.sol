// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../common/ImmutableOwnable.sol";
import "../common/TransferHelper.sol";
import { HUNDRED_PERCENT } from "../common/Constants.sol";

contract OnboardingController is ImmutableOwnable {
    using TransferHelper for address;

    // solhint-disable var-name-mixedcase

    uint256 private constant ZERO_REWARD = 0;

    address public immutable ZACCOUNT_REGISTRY;
    address public immutable ZKP_TOKEN;
    address public immutable VAULT;
    address public immutable RESERVE_CONTROLLER;

    // solhint-enable var-name-mixedcase

    struct RewardParams {
        // reserved bytes
        uint128 _unused;
        // kyc provider ratio from zkpRewardsPerActivation
        uint16 zkpRate;
        // user ratio from zkpRewardsPerActivation
        uint16 zZkpRate;
        // zkp reward to be grant on each call.
        uint96 rewardsPerGrant;
    }

    RewardParams public rewardParams;

    uint128 public rewardsGranted;
    uint128 public rewardsLimit;

    mapping(address => bool) public isUserRewarded;

    event RewardParamsUpdated(
        uint96 rewardsPerGrant,
        uint16 zkpRate,
        uint16 zZkpRate
    );
    event RewardsLimtUpdated(uint256 rewardsLimit);
    event ZzkpAllocated(address user, uint256 amount);
    event ReserveControllerApproved(uint256 amount);

    constructor(
        address _owner,
        address _zkpToken,
        address _zAccountRegistry,
        address _vault,
        address _reserveController
    ) ImmutableOwnable(_owner) {
        require(
            _zAccountRegistry != address(0) &&
                _zkpToken != address(0) &&
                _vault != address(0),
            "init: zero address"
        );

        ZACCOUNT_REGISTRY = _zAccountRegistry;
        ZKP_TOKEN = _zkpToken;
        VAULT = _vault;
        RESERVE_CONTROLLER = _reserveController;
    }

    function updateRewardParams(
        uint96 _rewardsPerGrant,
        uint16 _zkpRate,
        uint16 _zZkpRate
    ) external onlyOwner {
        // if _rewardsPerGrant is defined, then sum of ratios should be 10000
        // setting _rewardsPerGrant to 0 disables the program
        require(
            _rewardsPerGrant == 0 || (_zkpRate + _zZkpRate == HUNDRED_PERCENT),
            "invalid zkp ratio"
        );

        rewardParams = RewardParams({
            _unused: uint128(0),
            zkpRate: _zkpRate,
            zZkpRate: _zZkpRate,
            rewardsPerGrant: _rewardsPerGrant
        });

        emit RewardParamsUpdated(_rewardsPerGrant, _zkpRate, _zZkpRate);
    }

    function updateRewardsLimitAndVaultAllowance() external {
        // Getting the current allowance of ReserveController
        uint256 reserveControllerAllowance = ZKP_TOKEN.safeAllowance(
            address(this),
            RESERVE_CONTROLLER
        );
        uint256 _rewardsLimit = rewardsLimit;

        // Getting the unused rewards limit
        uint256 unusedLimit = _rewardsLimit - rewardsGranted;

        // The availabe balance (part of the balance is reserved and will be withdrawn from ReserveController)
        uint256 available = ZKP_TOKEN.safeBalanceOf(address(this)) -
            reserveControllerAllowance;

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

    function grantRewards(
        address _user,
        uint8 _prevStatus,
        uint8 _newStatus,
        bytes memory _data
    ) external returns (uint256 _zZkpRewardAlloc) {
        _zZkpRewardAlloc = 100e18;

        // require(msg.sender == ZACCOUNT_REGISTRY, "unauthorized");

        // RewardParams memory _rewardParams = rewardParams;

        // uint256 _rewardsGranted = rewardsGranted +
        //     (_rewardParams.rewardsPerGrant);

        // if (rewardsLimit >= _rewardsGranted) {
        //     _zZkpRewardAlloc = _getZzkpRewardsAllocation(_rewardParams, _user);

        //     _increaseReserveControllerAllowance(_rewardParams);

        //     rewardsGranted = uint128(_rewardsGranted);
        // }
    }

    function _getZzkpRewardsAllocation(
        RewardParams memory _rewardParams,
        address _user
    ) private returns (uint256 _zZkpRewardAlloc) {
        // return 0 if has already got rewarded
        if (isUserRewarded[_user]) return (_zZkpRewardAlloc);

        // Calculate ZKP rewards allocation
        _zZkpRewardAlloc =
            ((_rewardParams.rewardsPerGrant) * _rewardParams.zZkpRate) /
            HUNDRED_PERCENT;

        if (_zZkpRewardAlloc > ZERO_REWARD) {
            isUserRewarded[_user] = true;

            emit ZzkpAllocated(_user, _zZkpRewardAlloc);
        }
    }

    function _increaseReserveControllerAllowance(
        RewardParams memory _rewardParams
    ) private {
        uint256 _zkpRewardAlloc = ((_rewardParams.rewardsPerGrant) *
            _rewardParams.zkpRate) / HUNDRED_PERCENT;

        if (_zkpRewardAlloc > ZERO_REWARD) {
            ZKP_TOKEN.safeIncreaseAllowance(
                RESERVE_CONTROLLER,
                _zkpRewardAlloc
            );

            emit ReserveControllerApproved(_zkpRewardAlloc);
        }
    }
}
