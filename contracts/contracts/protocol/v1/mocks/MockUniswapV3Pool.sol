pragma solidity ^0.8.19;

import "../DeFi/uniswap/interfaces/IUniswapV3SwapCallback.sol";
import "../DeFi/uniswap/libraries/TickMath.sol";
import "../../../common/ImmutableOwnable.sol";
import "../../../common/TransferHelper.sol";
import "../../../staking/interfaces/IErc20Min.sol";
import "../DeFi/UniswapV3PriceFeed.sol";
import "hardhat/console.sol";

interface IUniswapV3PoolDeployer {
    function parameters() external view returns (
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    );
}

interface IMockUniswapV3Factory {
    function feeMaster() external view returns (address);
}

contract MockUniswapV3Pool is ImmutableOwnable {

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;

    uint128 public liquidity = 1000000 ether; // Arbitrary constant liquidity for simplicity

    using UniswapV3PriceFeed for address;

    constructor(address _owner) ImmutableOwnable(_owner){
        (factory, token0, token1, fee,) = IUniswapV3PoolDeployer(msg.sender).parameters();
    }


    uint160 public currSqrtPriceX96;
    int24 currTick;

    function setCurrSqrtPriceAndTick(uint160 sqrtPriceX96) public {
        currSqrtPriceX96 = sqrtPriceX96;
        currTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    function initialize(uint160 sqrtPriceX96) external {
        setCurrSqrtPriceAndTick(sqrtPriceX96);
    }

    function observations(uint256) external pure returns (uint32, int56, uint160, bool) {
        return (0, 0, 0, true);
    }

    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked) {
        sqrtPriceX96 = currSqrtPriceX96;

        // These fields are tested with the real uniswap core contracts:
        observationIndex = observationCardinality = observationCardinalityNext = 1;

        // Not used in our ests:
        tick = 0;
        feeProtocol = 0;
        unlocked = false;
    }

    //tickCumulatives The tick * time elapsed since the pool was first initialized, as of each `secondsAgo'

    function observe(uint32[] calldata secondsAgos)
    external
    view
    returns (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives)
    {
        uint len = secondsAgos.length;
        tickCumulatives = new int56[](len);
        liquidityCumulatives = new uint160[](len);

        // Assume the current time is block.timestamp for simplicity
        uint32 currentTime = uint32(block.timestamp);

    for (uint i = 0; i < len; i++) {
            uint32 queryTime = currentTime - secondsAgos[i];
            // Calculate tickCumulative as if the tick has been constant throughout
            tickCumulatives[i] = currTick * int56(uint56(queryTime));
            // Simple constant return for liquidityCumulative, not necessarily realistic
            liquidityCumulatives[i] = liquidity;
        }

        return (tickCumulatives, liquidityCumulatives);
    }




    function setTestLiquidity(uint128 newLiquidity) external {
        liquidity = newLiquidity;
    }


    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external isFeeMasterOrOwner() {

        require(amountSpecified > 0, 'Amount must be positive');

        // Calculate both amounts in one go
        (uint256 amount0, uint256 amount1) = calculateAmount(zeroForOne, sqrtPriceLimitX96, uint256(amountSpecified));

        // Transfer tokens and perform swap callbacks based on the swap direction
        if (zeroForOne) {
            TransferHelper.safeTransfer(token1, recipient, amount1);
            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amountSpecified, int256(amount1), data);
            require(balance1Before + amount1 <= balance1(), 'Invalid balance after swap');
        } else {
            TransferHelper.safeTransfer(token0, recipient, amount0);
            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(-int256(amount0), int256(amountSpecified), data);
            require(balance0Before + amount0 <= balance0(), 'Invalid balance after swap');
        }
    }


    /// @dev Get the pool's balance of token0
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) =
        token0.staticcall(abi.encodeWithSelector(IErc20Min.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get the pool's balance of token1
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) =
        token1.staticcall(abi.encodeWithSelector(IErc20Min.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function calculateAmount(
        bool zeroForOne,
        uint160 sqrtPriceX96,
        uint256 amountSpecified
    ) public pure returns (uint256 amount0, uint256 amount1) {
        require(sqrtPriceX96 > 0, "sqrtPriceX96 cannot be zero");

        uint256 priceX96 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        if (zeroForOne) {
            amount0 = amountSpecified;
            amount1 = amount0 * priceX96 >> 192;  // Convert amount0 to amount1
        } else {
            amount1 = amountSpecified;
            amount0 = (amount1 << 192) / priceX96;  // Convert amount1 to amount0
        }
    }

    modifier isFeeMasterOrOwner() {
        require(
            OWNER == msg.sender || IMockUniswapV3Factory(factory).feeMaster() == msg.sender,
            "ERR_NOT_FEE_MASTER_OR_OWNER"
        );
        _;
    }


    function getQuoteAmount(
        bool zeroForOne,
        uint256 inputAmount,
        uint256 twapPeriod
    ) public view returns (uint256) {
        require(twapPeriod != 0, "twap0");
        if (zeroForOne) {
            return address(this).getQuoteAmount(token0, token1, inputAmount, twapPeriod);
        } else {
            return address(this).getQuoteAmount(token1, token0, inputAmount, twapPeriod);
        }

    }

}
