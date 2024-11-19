// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../../../../common/TransferHelper.sol";
import { MAX_PRP_AMOUNT, ERC20_TOKEN_TYPE } from "../../../../../common/Constants.sol";

import "../../publicSignals/PrpConversionPublicSignals.sol";
import "../../errMsgs/PrpConverterErrMsgs.sol";

import "../../../../../common/UtilsLib.sol";
import { LockData } from "../../../../../common/Types.sol";

import "../../libraries/VaultExecutor.sol";

abstract contract ConversionHandler {
    using VaultExecutor for address;
    using UtilsLib for uint256;
    using TransferHelper for uint256;
    using TransferHelper for address;

    address internal immutable VAULT;

    uint64 private prpReserve;
    uint96 private zkpReserve;
    uint32 private blockTimestampLast;

    event Sync(uint112 prpReserve, uint112 zkpReserve);

    constructor(address vault) {
        VAULT = vault;
    }

    function getReserves()
        public
        view
        returns (
            uint256 _prpReserve,
            uint256 _zkpReserve,
            uint32 _blockTimestampLast
        )
    {
        _prpReserve = prpReserve;
        _zkpReserve = zkpReserve;
        _blockTimestampLast = blockTimestampLast;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(
            amountIn > 0 && reserveIn > 0 && reserveOut > 0,
            ERR_INSUFFICIENT_AMOUNT_IN_OR_RESERVES
        );
        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }

    function _processConversion(
        address zkpToken,
        uint96 zkpAmountOutMin,
        uint256[] calldata inputs
    ) internal returns (uint256 zkpAmountOutScaled) {
        uint256 prpWithdrawAmount;
        {
            prpWithdrawAmount = inputs[PRP_CONVERSION_WITHDRAW_PRP_AMOUNT_IND];
            uint256 prpDepositAmount = inputs[
                PRP_CONVERSION_DEPOSIT_PRP_AMOUNT_IND
            ];
            // this function is not supposed to add (aka deposit) prp to zAccount
            require(prpDepositAmount == 0, ERR_NON_ZERO_DEPOSIT_AMOUNT_PRP);
            // the prp withdraw amount (i.e. the prp that gonna be burn) should be less than prp total supply
            require(
                prpWithdrawAmount <= MAX_PRP_AMOUNT,
                ERR_TOO_LARGE_PRP_AMOUNT
            );
        }

        (uint256 _prpReserve, uint256 _zkpReserve, ) = getReserves();
        require(_zkpReserve > 0, ERR_INSUFFICIENT_LIQUIDITY);

        uint256 zkpAmountOut;
        uint96 zkpAmountOutRounded;
        uint256 scale = inputs[PRP_CONVERSION_ZASSET_SCALE_IND];

        {
            zkpAmountOut = getAmountOut(
                prpWithdrawAmount,
                _prpReserve,
                _zkpReserve
            );

            require(zkpAmountOut >= scale, ERR_INSUFFICIENT_AMOUNT_OUT);
            require(zkpAmountOut >= zkpAmountOutMin, ERR_LOW_AMOUNT_OUT);

            zkpAmountOutScaled = zkpAmountOut / scale;

            unchecked {
                // rounding the amount (leaving the changes in the contract)
                zkpAmountOutRounded = (zkpAmountOutScaled * scale).safe96();
            }

            require(zkpAmountOutRounded < _zkpReserve, ERR_LOW_LIQUIDITY);
        }

        _lockZkp(zkpToken, zkpAmountOutRounded);

        uint256 prpVirtualBalance = _prpReserve + prpWithdrawAmount;
        uint256 zkpBalance = zkpToken.safeBalanceOf(address(this));

        require(
            prpVirtualBalance * zkpBalance >= _prpReserve * _zkpReserve,
            ERR_LOW_CONSTANT_PRODUCT
        );

        _update(prpVirtualBalance, zkpBalance);
    }

    function _update(uint256 prpVirtualBalance, uint256 zkpBalance) internal {
        prpReserve = prpVirtualBalance.safe64();
        zkpReserve = zkpBalance.safe96();
        blockTimestampLast = block.timestamp.safe32();
        emit Sync(prpReserve, zkpReserve);
    }

    function _lockZkp(address zkpToken, uint256 amount) internal {
        VAULT.lockAsset(
            LockData(
                ERC20_TOKEN_TYPE,
                zkpToken,
                // tokenId undefined for ERC-20
                0,
                address(this),
                amount.safe96()
            )
        );
    }
}
