// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "../../../common/TransferHelper.sol";
import "../../../common/interfaces/IWETH.sol";
import "./MockCallbackValidation.sol";
import "../DeFi/uniswap/libraries/TickMath.sol";
import "../DeFi/uniswap/interfaces/IUniswapV3Pool.sol";
import "./MockPoolAddress.sol";
import "../DeFi/uniswap/libraries/SafeCast.sol";
import "../DeFi/uniswap/interfaces/IUniswapV3SwapCallback.sol";
import "../DeFi/uniswap/Types.sol";

contract MockUniSwapV3Router {
    using SafeCast for uint256;

    address public immutable WETH9;
    address public immutable FACTORY;

    constructor(address _factory, address _weth) {
        WETH9 = _weth;
        FACTORY = _factory;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        require(amount0Delta > 0 || amount1Delta > 0, "not zero");

        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, uint24 fee, address tokenOut) = decodePath(data.path);
        MockCallbackValidation.verifyCallback(FACTORY, tokenIn, tokenOut, fee);

        (bool isExactInput, uint256 amountToPay) = amount0Delta > 0
            ? (tokenIn < tokenOut, uint256(amount0Delta))
            : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            tokenIn = tokenOut;
            // swap in/out because exact output swaps are reversed
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        }
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut) {
        bool zeroForOne = params.tokenIn < params.tokenOut;

        SwapCallbackData memory data = SwapCallbackData({
            path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut),
            payer: msg.sender
        });

        (int256 amount0, int256 amount1) = getPool(
            params.tokenOut,
            params.tokenIn,
            params.fee
        ).swap(
                params.recipient,
                zeroForOne,
                params.amountIn.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : params.sqrtPriceLimitX96,
                abi.encode(data)
            );

        amountOut = uint256((zeroForOne ? amount1 : amount0));

        require(amountOut >= params.amountOutMinimum, "Too little received");
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
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

    function deposit() public payable {
        IWETH(WETH9).deposit{ value: msg.value }();
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (token == WETH9 && address(this).balance >= value) {
            // pay with WETH9
            IWETH(WETH9).deposit{ value: value }();
            // wrap only what is needed to pay
            IWETH(WETH9).transfer(recipient, value);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }

    function decodePath(
        bytes memory data
    ) internal pure returns (address tokenIn, uint24 fee, address tokenOut) {
        require(data.length == 20 + 3 + 20, "Invalid data length");
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Load tokenIn (first 20 bytes)
            tokenIn := shr(96, mload(add(data, 32)))

            // Load fee (next 3 bytes)
            fee := mload(add(data, 52))
            fee := shr(232, fee) // uint24 is 3 bytes, so we shift right by 232 bits

            // Load tokenOut (last 20 bytes)
            tokenOut := shr(96, mload(add(data, 55)))
        }
    }

    receive() external payable {}
}
