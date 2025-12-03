// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./interfaces/IFeeMaster.sol";
import "./interfaces/IProviderFeeDebt.sol";
import "./interfaces/IProtocolFeeDistributor.sol";
import "./interfaces/IPayMasterDepositThreshold.sol";
import "./interfaces/IZkpReserveController.sol";
import "./core/interfaces/IVoucherTerms.sol";
import "../../common/Constants.sol";

/**
 * @title PrpRewardEstimator
 * @author Pantherprotocol Contributors
 * @notice Helper contract to estimate PRP rewards and ZKP distributions across various protocol components
 * @dev This contract aggregates reward calculations from multiple sources including FeeMaster,
 *      ZkpReserveController, and PayMaster to provide total estimated rewards
 */
contract PrpRewardEstimator {
    /// @notice Address of the FeeMaster contract
    address public immutable FEE_MASTER;
    /// @notice Address of the PayMaster contract
    address public immutable PAY_MASTER;
    /// @notice Address of the ZkpReserveController contract
    address public immutable ZKP_RESERVE_CONTROLLER;
    /// @notice Address of the PrpVoucherController contract
    address public immutable PRP_VOUCHER_CONTROLLER;

    /**
     * @notice Initializes the PrpRewardEstimator contract
     * @param feeMaster Address of the FeeMaster contract
     * @param payMaster Address of the PayMaster contract
     * @param zkpReserveController Address of the ZkpReserveController contract
     * @param prpVoucherController Address of the PrpVoucherController contract
     */
    constructor(
        address feeMaster,
        address payMaster,
        address zkpReserveController,
        address prpVoucherController
    ) {
        FEE_MASTER = feeMaster;
        PAY_MASTER = payMaster;
        ZKP_RESERVE_CONTROLLER = zkpReserveController;
        PRP_VOUCHER_CONTROLLER = prpVoucherController;
    }

    /**
     * @notice Estimates total PRP rewards and ZKP tokens to be sent to PRP converter
     * @param zAssets Array of zAsset addresses to calculate rewards for
     * @return prpRewards Total estimated PRP rewards
     * @return zkpsToBeSendToPrpConverter Total ZKP tokens to be sent to PRP converter
     */
    function estimateTotalPrpRewardsAndReleasableZkps(
        address[] calldata zAssets
    )
        external
        view
        returns (uint256 prpRewards, uint256 zkpsToBeSendToPrpConverter)
    {
        // Get estimated rewards from FeeMaster
        (uint256 estimatedPrpRewards, uint256 estimatedZkpBalance) = IFeeMaster(
            FEE_MASTER
        ).estimateRebalancingPrpRewardsAndZkpBalance(zAssets);
        prpRewards = estimatedPrpRewards;

        // Calculate ZKPs for PRP converter and treasury distribution
        zkpsToBeSendToPrpConverter = calculatePrpConverterZkpShare(
            estimatedZkpBalance
        );
        prpRewards += calculateDistributionPrpRewards(estimatedZkpBalance);

        // Add ZkpReserveController rewards
        uint256 zkpReserveControllerReleasableZkp = IZkpReserveController(
            ZKP_RESERVE_CONTROLLER
        ).releasableAmount();

        zkpsToBeSendToPrpConverter += zkpReserveControllerReleasableZkp;
        prpRewards += calculateZkpReserveControllerPrpRewards(
            zkpReserveControllerReleasableZkp
        );

        // Add PayMaster rewards
        prpRewards += calculatePayMasterPrpRewards();
    }

    /**
     * @notice Calculates the amount of ZKPs to be sent to PRP converter
     * @param estimatedZkpBalance Total ZKP balance to calculate from
     * @return Amount of ZKPs allocated for PRP converter
     */
    function calculatePrpConverterZkpShare(
        uint256 estimatedZkpBalance
    ) public view returns (uint256) {
        uint256 treasuryPercentage = IProtocolFeeDistributor(FEE_MASTER)
            .treasuryLockPercentage();

        uint256 prpConverterZkpPercentage = HUNDRED_PERCENT -
            treasuryPercentage;

        return
            (estimatedZkpBalance * prpConverterZkpPercentage) / HUNDRED_PERCENT;
    }

    /**
     * @notice Calculates PRP rewards from ZKP distribution
     * @param totalFeeMasterZkps Total ZKPs in FeeMaster
     * @return prpRewards Calculated PRP rewards
     */
    function calculateDistributionPrpRewards(
        uint256 totalFeeMasterZkps
    ) public view returns (uint256 prpRewards) {
        uint256 feeMasterMinRewardableZkpAmount = IFeeMaster(FEE_MASTER)
            .minRewardableZkpAmount();

        if (totalFeeMasterZkps > feeMasterMinRewardableZkpAmount) {
            prpRewards = getVoucherRewardAmount(FEE_MASTER, GT_ZKP_DISTRIBUTE);
        }
    }

    /**
     * @notice Calculates PRP rewards from ZkpReserveController
     * @param zkpReserveControllerReleasableZkp Releasable ZKP amount from controller
     * @return prpRewards Calculated PRP rewards
     */
    function calculateZkpReserveControllerPrpRewards(
        uint256 zkpReserveControllerReleasableZkp
    ) public view returns (uint256 prpRewards) {
        (
            ,
            uint256 zkpReserveControllerMinRewardableAmount,
            ,
            ,

        ) = IZkpReserveController(ZKP_RESERVE_CONTROLLER).getRewardStats();

        if (
            zkpReserveControllerReleasableZkp >=
            zkpReserveControllerMinRewardableAmount
        ) {
            prpRewards = getVoucherRewardAmount(
                ZKP_RESERVE_CONTROLLER,
                GT_ZKP_RELEASE
            );
        }
    }

    /**
     * @notice Calculates PRP rewards from PayMaster
     * @return prpRewards Calculated PRP rewards
     */
    function calculatePayMasterPrpRewards()
        public
        view
        returns (uint256 prpRewards)
    {
        uint256 payMasterDepositThreshold = IPayMasterDepositThreshold(
            PAY_MASTER
        ).depositThreshold();

        uint256 paymasterClaimAmount = IProviderFeeDebt(FEE_MASTER).debts(
            PAY_MASTER,
            NATIVE_TOKEN
        );

        if (
            payMasterDepositThreshold > 0 &&
            paymasterClaimAmount >= payMasterDepositThreshold
        ) {
            prpRewards = getVoucherRewardAmount(
                PAY_MASTER,
                GT_PAYMASTER_REFUND
            );
        }
    }

    /**
     * @notice Gets the reward amount from a voucher
     * @param rewardIssuer Address of the contract issuing the reward
     * @param voucherType Type of voucher to get reward amount for
     * @return Reward amount from the voucher
     */
    function getVoucherRewardAmount(
        address rewardIssuer,
        bytes4 voucherType
    ) public view returns (uint256) {
        VoucherTerms memory voucherTerm = IVoucherTerms(PRP_VOUCHER_CONTROLLER)
            .getVoucherTerms(rewardIssuer, voucherType);
        return voucherTerm.amount;
    }
}
