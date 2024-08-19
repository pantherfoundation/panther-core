// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar

/**
 * @title AMMRefill
:q
 * @notice This contract is designed to refill the PRP-to-$ZKP AMM with $ZKP tokens.
 * @dev The contract calculates the releasable amount of tokens using a formula and sends
 * those tokens to the AMM when triggered by a user. Users who trigger a refill that
 * surpasses a minimum reward threshold are rewarded with PRP tokens via the PRPVoucherGrantor contract.
 */

pragma solidity ^0.8.16;

import "./interfaces/IPrpVoucherGrantor.sol";
import { GT_AMM_REFILL } from "../../common/Constants.sol";
import "../../common/UtilsLib.sol";
import "../../common/ImmutableOwnable.sol";
import "../../common/TransferHelper.sol";
import "./errMsgs/AMMRefillErrMsgs.sol";

contract AMMRefill is ImmutableOwnable {
    using TransferHelper for address;
    using TransferHelper for address payable;
    using UtilsLib for uint256;

    struct Params {
        uint64 releasableEveryBlock;
        uint64 minimalRewardableAmount;
        uint64 releasedAmount;
        uint64 offset;
    }

    Params public params;

    address public immutable ZKP_TOKEN;
    address public immutable AMM;
    IPrpVoucherGrantor public immutable PRP_VOUCHER_GRANTOR;

    event Refilled(bytes32 saltHash, uint64 amount, uint64 reward);
    event ParamsUpdated(
        uint64 releasableEveryBlock,
        uint64 minimalRewardedAmount
    );

    error NothingToRelease();

    /**
     * @notice Constructor to initialize the AMMRefill contract.
     * @param _zkpToken The address of the ZKP token contract.
     * @param _amm The address of the AMM contract to receive ZKP tokens.
     * @param _prpVoucherGrantor The address of the PRPVoucherGrantor contract for rewarding users.
     * @param _releasableEveryBlock The amount of ZKP tokens that can be released per block.
     * @param _minimalRewardedAmount The minimum amount of ZKP tokens that need to be released to reward the user.
     * @param _owner The address of the contract owner.
     */
    constructor(
        address _zkpToken,
        address _amm,
        address _prpVoucherGrantor,
        uint64 _releasableEveryBlock,
        uint64 _minimalRewardedAmount,
        address _owner
    ) ImmutableOwnable(_owner) {
        require(
            _releasableEveryBlock > 0 &&
                _minimalRewardedAmount > 0 &&
                _zkpToken != address(0) &&
                _amm != address(0) &&
                _prpVoucherGrantor != address(0),
            ERR_INVALID_PARAMS
        );
        ZKP_TOKEN = _zkpToken;
        AMM = _amm;
        PRP_VOUCHER_GRANTOR = IPrpVoucherGrantor(_prpVoucherGrantor);
        params.releasableEveryBlock = _releasableEveryBlock;
        params.minimalRewardableAmount = _minimalRewardedAmount;
        params.releasedAmount = 0;
        params.offset = params.releasableEveryBlock * block.number.safe64();
    }

    /**
     * @notice Updates the configuration parameters for the AMMRefill contract.
     * @dev Can only be called by the contract owner.
     * @param _releasableEveryBlock The new amount of ZKP tokens that can be released per block.
     * @param _minimalRewardedAmount The new minimum amount of ZKP tokens that need to be released to reward the user.
     */
    function updateParams(
        uint64 _releasableEveryBlock,
        uint64 _minimalRewardedAmount
    ) external onlyOwner {
        require(
            _releasableEveryBlock > 0 && _minimalRewardedAmount > 0,
            ERR_INVALID_PARAMS
        );
        params.releasableEveryBlock = _releasableEveryBlock;
        params.minimalRewardableAmount = _minimalRewardedAmount;
        params.offset = params.releasableEveryBlock * block.number.safe64();
        emit ParamsUpdated(_releasableEveryBlock, _minimalRewardedAmount);
    }

    /**
     * @notice Triggers a refill of the AMM with ZKP tokens.
     * @dev Calculates the releasable amount of tokens and sends them to the AMM.
     * If the releasable amount is above the minimal rewarded amount, the user is rewarded with PRP tokens.
     * @param saltHash A unique hash value used to distinguish between different refill actions.
     */
    function refill(bytes32 saltHash) external {
        uint64 releasableAmount = _releasableAmount();
        uint64 contractBalance = uint64(ZKP_TOKEN.safeBalanceOf(address(this)));

        if (releasableAmount > contractBalance) {
            releasableAmount = contractBalance;
        }

        require(releasableAmount > 0, ERR_INVALID_RELEASABLE_AMOUNT);

        params.offset += releasableAmount;
        params.releasedAmount += releasableAmount;

        ZKP_TOKEN.safeTransfer(AMM, releasableAmount);

        uint64 rewardAmount = 0;
        if (releasableAmount >= params.minimalRewardableAmount) {
            rewardAmount = releasableAmount;
            PRP_VOUCHER_GRANTOR.generateRewards(
                saltHash,
                rewardAmount,
                GT_AMM_REFILL
            );
        }

        emit Refilled(saltHash, releasableAmount, rewardAmount);
    }

    /**
     * @notice Returns the current releasable amount of ZKP tokens based on the configuration.
     * @return uint64 The amount of ZKP tokens that can currently be released.
     */
    function releasableAmount() external view returns (uint64) {
        return _releasableAmount();
    }

    /**
     * @dev Internal function to calculate the releasable amount of ZKP tokens.
     * @return uint64 The amount of ZKP tokens that can currently be released.
     */
    function _releasableAmount() private view returns (uint64) {
        return
            (params.releasableEveryBlock * block.number.safe64()) -
            params.offset;
    }
}
