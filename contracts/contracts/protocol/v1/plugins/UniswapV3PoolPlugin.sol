// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../common/TransferHelper.sol";
import "../../../common/Types.sol";
import "../mocks/MockCallbackValidation.sol";
import "../mocks/MockPoolAddress.sol";
import "../DeFi/UniswapV3FlashSwap.sol";
import "../interfaces/IPlugin.sol";

contract UniswapV3PoolPlugin is IPlugin {
    address public immutable FACTORY;

    using UniswapV3FlashSwap for address;
    using TransferHelper for address;
    using TransferHelper for address payable;

    uint24 public fee = 500;

    constructor(address _factory) {
        FACTORY = _factory;
    }

    /**
     * @dev Params specific to UnipluginParamsV3
     */

    struct Params {
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        uint24 fee;
    }

    function exec(
        PluginData calldata pluginParams
    ) external returns (uint256 amountOut) {
        Params memory params = abi.decode(pluginParams.userData, (Params));

        IUniswapV3Pool pool = getPool(
            pluginParams.lDataIn.token,
            pluginParams.lDataOut.token,
            params.fee
        );

        (int256 amount0, int256 amount1) = pool.swap(
            pluginParams.lDataIn.token,
            true,
            int256(uint256(pluginParams.lDataIn.extAmount)),
            params.sqrtPriceLimitX96,
            new bytes(0)
        );

        // TODO amounts
        (amount0, amount1);
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

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        // TODO data
        (data);
        MockCallbackValidation.verifyCallback(
            FACTORY,
            IUniswapV3Pool(msg.sender).token0(),
            IUniswapV3Pool(msg.sender).token1(),
            fee
        );

        if (amount0Delta > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token0()).transfer(
                msg.sender,
                uint256(amount0Delta)
            );
        } else if (amount1Delta > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token1()).transfer(
                msg.sender,
                uint256(amount1Delta)
            );
        } else {
            // if both are not gt 0, both must be 0.
            assert(amount0Delta == 0 && amount1Delta == 0);
        }
    }
}
