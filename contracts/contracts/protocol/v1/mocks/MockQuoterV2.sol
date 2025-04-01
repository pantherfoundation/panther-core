// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.19;

import "../DeFi/uniswap/interfaces/IQuoterV2.sol";
import "../DeFi/uniswap/interfaces/IUniswapV3Pool.sol";
import "./MockPoolAddress.sol";
import "../DeFi/uniswap/libraries/TickMath.sol";
import "../DeFi/uniswap/libraries/SafeCast.sol";

/// @title Provides quotes for swaps
/// @notice Allows getting the expected amount out or amount in for a given swap without executing the swap
/// @dev These functions are not gas efficient and should _not_ be called on chain. Instead, optimistically execute
/// the swap and check the amounts in the callback.
contract MockQuoterV2 is IQuoterV2 {
    using SafeCast for uint256;

    address public immutable WETH9;
    address public immutable FACTORY;

    constructor(address _factory, address _weth) {
        WETH9 = _weth;
        FACTORY = _factory;
    }

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (IUniswapV3Pool) {
        return
            IUniswapV3Pool(
                MockPoolAddress.computeAddress(
                    FACTORY,
                    MockPoolAddress.getPoolKey(tokenA, tokenB, fee)
                )
            );
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(
        bytes memory reason
    )
        private
        pure
        returns (uint256 amount, uint160 sqrtPriceX96After, int24 tickAfter)
    {
        if (reason.length != 96) {
            if (reason.length < 68) revert("Unexpected error");
            // solhint-disable-next-line no-inline-assembly
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256, uint160, int24));
    }

    function handleRevert(
        bytes memory reason,
        IUniswapV3Pool pool,
        uint256 gasEstimate
    )
        private
        view
        returns (
            uint256 amount,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256
        )
    {
        int24 tickBefore;
        int24 tickAfter;
        (, tickBefore, , , , , ) = pool.slot0();
        (amount, sqrtPriceX96After, tickAfter) = parseRevertReason(reason);

        initializedTicksCrossed = 1;

        return (
            amount,
            sqrtPriceX96After,
            initializedTicksCrossed,
            gasEstimate
        );
    }

    function quoteExactInputSingle(
        QuoteExactInputSingleParams memory params
    )
        public
        override
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        bool zeroForOne = params.tokenIn < params.tokenOut;
        IUniswapV3Pool pool = getPool(
            params.tokenIn,
            params.tokenOut,
            params.fee
        );

        uint256 gasBefore = gasleft();
        try
            pool.swap(
                address(this), // address(0) might cause issues with some tokens
                zeroForOne,
                params.amountIn.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : params.sqrtPriceLimitX96,
                abi.encodePacked(params.tokenIn, params.fee, params.tokenOut)
            )
        // solhint-disable-next-line no-empty-blocks
        {

        } catch (bytes memory reason) {
            gasEstimate = gasBefore - gasleft();
            return handleRevert(reason, pool, gasEstimate);
        }
    }
}
