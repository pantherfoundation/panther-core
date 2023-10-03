// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../common/ImmutableOwnable.sol";
import "../common/TransferHelper.sol";
import "../common/Claimable.sol";
import "../common/NonReentrant.sol";

import "./interfaces/IPrpGranter.sol";
import "./interfaces/IZkpPriceOracle.sol";
import "./actions/Constants.sol";
import "./errMsgs/FeeBrokerErrMsgs.sol";

/***
 * @title FeeBroker
 * @notice It collects fee tokens, exchange them for ZKP and transfer its ZKP balance to the
 * PRP converter and Treasury contracts.
 * @dev This contract is supposed to transfer the fee token from panther shielded pool. It let's
 * users to sell their ZKPs for the collected fee tokens. Users needs to define the exact amount
 * of ZKP which they aim to sell, then this contract used Uniswap v3 as price oracle to calculate
 * the fee token which can be sent to them. At the end of the day, some portion of the ZKP
 * balance of this contract can be sent to the PrpConverter and the rest can go to
 * the PantherTreasury. Users who exchange their ZKPs for fee tokens or trigger this contract to
 * move its ZKP balance to the PRP converter and Treasury are granted PRPs as rewards.
 ***/
contract FeeBroker is ImmutableOwnable, Claimable, NonReentrant {
    // solhint-disable var-name-mixedcase

    // Address of the $ZKP token contract
    address private immutable ZKP_TOKEN;

    /// @notice PrpConverter contract instance
    address public immutable PRP_CONVERTER;

    /// @notice PrpGranter contract instance
    address public immutable PRP_GRANTER;

    /// @notice PantherPoolV0 contract instance
    address public immutable PANTHER_POOL;

    /// @notice Panther treasury contract instance
    address public immutable PANTHER_TREASURY;

    /// @notice The divider which represents total percentages. scaled by 1e2
    uint256 private constant DIVIDER = 100_00;

    /// @notice Address of the ZkpPriceOracle contract
    IZkpPriceOracle public ZkpPriceOracle;

    // solhint-enable var-name-mixedcase

    /// @notice The percentage of ZKPs that are transfered to treasury
    uint256 public treasuryPercentage;

    event TreasuryPercentageUpdated(uint256 newPercentage);
    event ZkpPriceOracleUpdated(address newZkpPriceOracle);
    event Swapped(
        address exchanger,
        address recipient,
        address feeToken,
        uint256 zkpAmount,
        uint256 feeTokenAmount
    );
    event FeeCollected(address token, uint256 amount);
    event TransferredZkpToTreasuryAndPrpConverter(
        uint256 totalZkps,
        uint256 treasuryPortion
    );

    constructor(
        address _owner,
        address zkpToken,
        address prpConverter,
        address prpGranter,
        address pantherPool,
        address pantherTreasury,
        address zkpPriceOracle
    ) ImmutableOwnable(_owner) {
        require(
            zkpToken != address(0) &&
                prpConverter != address(0) &&
                prpGranter != address(0) &&
                pantherPool != address(0) &&
                pantherTreasury != address(0) &&
                zkpPriceOracle != address(0),
            ERR_ZERO_ADDRESS
        );

        ZKP_TOKEN = zkpToken;
        PRP_CONVERTER = prpConverter;
        PRP_GRANTER = prpGranter;
        PANTHER_POOL = pantherPool;
        PANTHER_TREASURY = pantherTreasury;

        ZkpPriceOracle = IZkpPriceOracle(zkpPriceOracle);
    }

    /// @notice Send ZKP balance to PrpConverter and PantherTreasury
    function transferZkpToTreasuryAndPrpConverter() external {
        uint256 totalZkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );
        if (totalZkpBalance < DIVIDER) return;

        uint256 treasuryPortion = (totalZkpBalance * treasuryPercentage) /
            DIVIDER;

        TransferHelper.safeTransfer(
            ZKP_TOKEN,
            PANTHER_TREASURY,
            treasuryPortion
        );

        TransferHelper.safeTransfer(
            ZKP_TOKEN,
            PRP_CONVERTER,
            totalZkpBalance - treasuryPortion
        );

        IPrpGranter(PRP_GRANTER).grant(
            ZKP_TRANSFER_TO_TREASURY_AND_PRP_CONVERTER_PRP_GRANT_TYPE,
            msg.sender
        );

        emit TransferredZkpToTreasuryAndPrpConverter(
            totalZkpBalance,
            treasuryPortion
        );
    }

    /// @notice Sell fee token to user and receive ZKP.
    function swapExactZkpTokenForFeeToken(
        address feeToken,
        uint256 zkpTokenAmountIn,
        uint256 feeTokenAmountOutMin,
        address recipient
    ) external nonReentrant {
        uint256 feeTokenAmountOut = ZkpPriceOracle.getFeeTokenAmountOut(
            feeToken,
            zkpTokenAmountIn
        );

        require(
            feeTokenAmountOut >= feeTokenAmountOutMin,
            ERR_LOW_OUTPUT_AMOUNT
        );

        require(
            TransferHelper.safeBalanceOf(feeToken, address(this)) >=
                feeTokenAmountOut,
            ERR_INSUFFICIENT_OUTPUT_BALANCE
        );

        TransferHelper.safeTransferFrom(
            ZKP_TOKEN,
            msg.sender,
            address(this),
            zkpTokenAmountIn
        );

        TransferHelper.safeTransfer(feeToken, recipient, feeTokenAmountOut);

        IPrpGranter(PRP_GRANTER).grant(
            ZKP_SWAP_FOR_FEE_TOKEN_PRP_GRANT_TYPE,
            msg.sender
        );

        emit Swapped(
            msg.sender,
            recipient,
            feeToken,
            zkpTokenAmountIn,
            feeTokenAmountOut
        );
    }

    /// @notice Collect fee tokens from PantherPool
    /// @dev Only PantherPool may call it.
    function collectFeeToken(address token, uint256 amount) external {
        require(msg.sender == PANTHER_POOL, ERR_UNAUTHORIZED);

        TransferHelper.safeTransferFrom(
            token,
            PANTHER_POOL,
            address(this),
            amount
        );

        emit FeeCollected(token, amount);
    }

    /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    function updateTreasuryPercentage(
        uint256 newPercentage
    ) external onlyOwner {
        require(newPercentage > 0, ERR_ZERO_TREASURY_PERCENTAGE);

        treasuryPercentage = newPercentage;

        emit TreasuryPercentageUpdated(newPercentage);
    }

    function updateZkpPriceOracle(
        address newZkpPriceOracle
    ) external onlyOwner {
        require(newZkpPriceOracle != address(0), ERR_ZERO_ADDRESS);
        ZkpPriceOracle = IZkpPriceOracle(newZkpPriceOracle);

        emit ZkpPriceOracleUpdated(newZkpPriceOracle);
    }

    /// @notice Withdraws accidentally sent token from this contract
    /// @dev May be only called by the {OWNER}
    function claimErc20(
        address claimedToken,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        _claimErc20(claimedToken, to, amount);
    }
}
