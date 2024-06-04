// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../../common/Types.sol";
import "../DeFi/uniswap/interfaces/ISwapRouter.sol";
import "../interfaces/IPlugin.sol";
import "../../../common/TransferHelper.sol";

contract UniswapV3Plugin is IPlugin {
    address public immutable ROUTER;

    using TransferHelper for address;
    using TransferHelper for address payable;

    /**
     * @dev Params specific to UnipluginParamsV3
     */

    struct Params {
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        uint24 fee;
    }

    constructor(address _router) {
        ROUTER = _router;
    }

    function exec(
        PluginData calldata pluginParams
    ) external returns (uint256 amountOut) {
        Params memory params = abi.decode(pluginParams.userData, (Params));

        ISwapRouter.ExactInputSingleParams
            memory pluginParamsParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: pluginParams.lDataIn.token,
                tokenOut: pluginParams.lDataOut.token,
                fee: params.fee,
                recipient: pluginParams.lDataOut.extAccount,
                deadline: params.deadline,
                amountIn: pluginParams.lDataIn.extAmount,
                amountOutMinimum: pluginParams.lDataOut.extAmount,
                sqrtPriceLimitX96: params.sqrtPriceLimitX96
            });

        pluginParams.lDataIn.token.safeApprove(ROUTER, 0);

        pluginParams.lDataIn.token.safeApprove(
            ROUTER,
            pluginParams.lDataIn.extAmount
        );

        try ISwapRouter(ROUTER).exactInputSingle(pluginParamsParams) returns (
            uint256 amount
        ) {
            amountOut = amount;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }
}
