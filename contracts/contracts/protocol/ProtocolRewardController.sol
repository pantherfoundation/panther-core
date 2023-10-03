// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../common/ImmutableOwnable.sol";
import "../staking/interfaces/IRewardPool.sol";
// import "./interfaces/IVestingPools.sol";
import "../staking/interfaces/IVestingPools.sol";

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

    /// @notice undefined pool id
    uint256 private constant UNDEF_POOL_ID = 0;
    /// @notice The maximum number of pool ids
    uint256 private constant MAX_POOL_LENGTH = 4;

    // Address of the $ZKP token contract
    address private immutable ZKP_TOKEN;

    /// @notice Address of the VestingPools instance
    address public immutable VESTING_POOLS;

    // solhint-enable var-name-mixedcase

    /// @notice ID of the pool (in the VestingPools) to vest from
    uint256[MAX_POOL_LENGTH] public poolIds;

    /// @notice Keep track of the RewardSenders
    mapping(address => bool) public rewardSenders;

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

    /// @notice Get array of pool ids
    function getPoolIds()
        external
        view
        returns (uint256[MAX_POOL_LENGTH] memory)
    {
        return poolIds;
    }

    /// @notice Sets/Updates the poolId
    /// @dev Owner only may call, once only
    /// This contract address must be set in the VestingPools as the wallet for the pool
    function updateVestingPool(uint8 _poolId, uint8 _index) external onlyOwner {
        require(_index < MAX_POOL_LENGTH, "PRC: invalid index");
        require(_poolId != UNDEF_POOL_ID, "PRC: zero pool id");

        // this contract must be registered with the VestingPools
        require(
            // slither-disable-next-line unused-return,reentrancy-events
            IVestingPools(VESTING_POOLS).getWallet(_poolId) == address(this),
            "PRC:E2"
        );

        poolIds[_index] = _poolId;

        emit VestingPoolUpdated(_poolId);
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
    function transferPoolWalletRole(
        uint8 _index,
        address _newWallet
    ) external onlyOwner nonZeroAddress(_newWallet) {
        uint256 _poolId = poolIds[_index];
        require(_poolId != UNDEF_POOL_ID, "PRC: Not found");

        poolIds[_index] = UNDEF_POOL_ID;

        // slither-disable-next-line reentrancy-benign
        IVestingPools(VESTING_POOLS).updatePoolWallet(_poolId, _newWallet);
    }

    /// @notice Release the tokens from VestingPools
    /// @dev RewardSender only may call
    function vestRewards() external returns (uint256 totalReleasable) {
        require(rewardSenders[msg.sender], "PRC:unauthorized");

        for (uint8 i; i < MAX_POOL_LENGTH; ) {
            uint256 _poolId = poolIds[i];

            if (_poolId == UNDEF_POOL_ID) continue;

            // slither-disable-next-line reentrancy-benign
            uint256 releasable = IVestingPools(VESTING_POOLS).releasableAmount(
                _poolId
            );

            if (releasable != 0) {
                IVestingPools(VESTING_POOLS).releaseTo(
                    _poolId,
                    msg.sender,
                    releasable
                );

                totalReleasable += releasable;
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
        for (uint8 i; i < MAX_POOL_LENGTH; ) {
            uint256 _poolId = poolIds[i];

            if (_poolId == UNDEF_POOL_ID) continue;

            // slither-disable-next-line reentrancy-benign
            _releasableAmount += IVestingPools(VESTING_POOLS).releasableAmount(
                _poolId
            );

            unchecked {
                ++i;
            }
        }
    }

    modifier nonZeroAddress(address account) {
        require(account != address(0), "RP: zero address");
        _;
    }
}
