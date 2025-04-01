// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../common/ImmutableOwnable.sol";
// TODO: moving this interfaces to common folder?
import "../../staking/interfaces/IRewardPool.sol";
import "../../staking/interfaces/IVestingPools.sol";

import "../../common/UtilsLib.sol";

/**
 * @title ProtocolRewardController
 * @author Pantherprotocol Contributors
 * @notice It has right to release tokens from the VestingPools. Only the
 * whitelisted RewardSenders can trigger this contract to release tokens.
 * @dev This contract lives on Ethereum chain and is able to release tokens from
 * VestingPools contract. It can whitelist the RewardSenders. Only whitelisted RewardSenders
 * can trigger this contract to release tokens. Each RewardSender can use a portion of
 * releasable amount. So, after triggering the release method by a RewardSender, if the is any
 * releasable amount, it does the math to calculate the portion that is allocated for
 * RewardSender and transfer the amount to it.
 */
contract ProtocolRewardController is ImmutableOwnable {
    // solhint-disable var-name-mixedcase

    /// @notice The maximum number of pool ids
    uint256 private constant MAX_POOL_IDS_LENGTH = 5;

    // Address of the $ZKP token contract
    address private immutable ZKP_TOKEN;

    /// @notice Address of the VestingPools instance
    address public immutable VESTING_POOLS;

    // solhint-enable var-name-mixedcase

    /// @notice Keep track of the RewardSenders
    mapping(address => bool) public rewardSenders;

    /// @notice 5 pool ids, 8 bytes for each of them
    uint40 public poolIds;

    /// @notice Emitted on parameters initialized.
    event VestingPoolUpdated(uint256 _poolId);

    /// @notice Emitted on adding RewardSender
    event RewardSenderUpdated(address rewardSender, bool whitelisted);

    /// @notice Emitted on vesting releasable amount to the recipient
    event Vested(address recipient, uint256 released);

    constructor(
        address _owner,
        address _zkpToken,
        address _vestingPools
    ) ImmutableOwnable(_owner) {
        require(
            _vestingPools != address(0) && _zkpToken != address(0),
            "PRC:E1"
        );

        ZKP_TOKEN = _zkpToken;
        VESTING_POOLS = _vestingPools;
    }

    // TODO: let contoller works works with pool with id 0
    function setPoolId(uint40 newPoolId, uint8 pos) external onlyOwner {
        require(pos > 0 && pos <= MAX_POOL_IDS_LENGTH, "PRC: invalid position");
        require(
            // slither-disable-next-line unused-return,reentrancy-events
            IVestingPools(VESTING_POOLS).getWallet(newPoolId) == address(this),
            "PRC:E2"
        );

        uint256 _poolIds = poolIds;
        uint256 currentPoolId = _getPoolId(pos);

        if (currentPoolId > 0) {
            _poolIds = _removePoolId(_poolIds, currentPoolId, pos);
        }

        if (newPoolId > 0) {
            _poolIds = _addPoolId(_poolIds, newPoolId, pos);
        }

        poolIds = uint40(_poolIds);
    }

    /// @notice Update the RewardSender contract address that will be able to release tokens
    /// @dev Owner only may call
    function updateRewardSender(
        address _rewardSender,
        bool _whitelisted
    ) external onlyOwner nonZeroAddress(_rewardSender) {
        require(
            rewardSenders[_rewardSender] != _whitelisted,
            "PRC: Sender is already updated"
        );

        rewardSenders[_rewardSender] = _whitelisted;

        emit RewardSenderUpdated(_rewardSender, _whitelisted);
    }

    /// @notice Calls VestingPools to transfer 'pool wallet' role to given address
    /// @dev Owner only may call, once only
    function transferVestingPoolWallet(
        uint8 _poolIdPos,
        address _newWallet
    ) external onlyOwner nonZeroAddress(_newWallet) {
        uint256 _poolId = _getPoolId(_poolIdPos);

        // this contract must be registered with the VestingPools
        require(
            // slither-disable-next-line unused-return,reentrancy-events
            IVestingPools(VESTING_POOLS).getWallet(_poolId) == address(this),
            "PRC:E2"
        );

        // slither-disable-next-line reentrancy-benign
        IVestingPools(VESTING_POOLS).updatePoolWallet(_poolId, _newWallet);

        poolIds = UtilsLib.safe40(_removePoolId(poolIds, _poolId, _poolIdPos));
    }

    /// @notice Release the tokens from VestingPools
    /// @dev RewardSender only may call
    function vestRewards() external returns (uint256 totalReleasable) {
        require(rewardSenders[msg.sender], "PRC:unauthorized");

        for (uint8 i = 1; i <= MAX_POOL_IDS_LENGTH; ) {
            uint256 _poolId = _getPoolId(i);

            if (_poolId > 0) {
                // slither-disable-next-line reentrancy-benign
                uint256 releasable = IVestingPools(VESTING_POOLS)
                    .releasableAmount(_poolId);

                if (releasable != 0) {
                    uint256 released = IVestingPools(VESTING_POOLS).releaseTo(
                        _poolId,
                        msg.sender,
                        releasable
                    );
                    assert(releasable == released);

                    totalReleasable += releasable;
                }
            }

            unchecked {
                ++i;
            }
        }

        emit Vested(msg.sender, totalReleasable);
    }

    /// @notice Get how many ZKP can be released at the moment
    function releasableAmount()
        external
        view
        returns (uint256 _releasableAmount)
    {
        //TODO: Define minimum amount which can be released.
        for (uint8 i = 1; i <= MAX_POOL_IDS_LENGTH; ) {
            uint256 _poolId = _getPoolId(i);

            if (_poolId > 0) {
                // slither-disable-next-line reentrancy-benign
                _releasableAmount += IVestingPools(VESTING_POOLS)
                    .releasableAmount(_poolId);
            }

            unchecked {
                ++i;
            }
        }
    }

    function _addPoolId(
        uint256 _poolIds,
        uint256 _poolId,
        uint8 _pos
    ) private pure returns (uint256 _updatedPoolIds) {
        _updatedPoolIds = _poolIds + (_poolId << ((_pos - 1) * 8));
    }

    function _removePoolId(
        uint256 _poolIds,
        uint256 _poolId,
        uint8 _pos
    ) private pure returns (uint256 _updatedPoolIds) {
        _updatedPoolIds = _poolIds - (_poolId << ((_pos - 1) * 8));
    }

    function _getPoolId(uint8 pos) private view returns (uint256) {
        uint256 res = (poolIds >> ((pos - 1) * 8)) & 255;
        return res;
    }

    modifier nonZeroAddress(address account) {
        require(account != address(0), "RP: zero address");
        _;
    }
}
