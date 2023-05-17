// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity 0.8.16;
// TODO: add one contract per file

import "../common/TransferHelper.sol";
import "../common/ImmutableOwnable.sol";
import "../common/Claimable.sol";

import "./errMsgs/PrpConverterErrMsgs.sol";

interface IPantherPool {
    function burnPrp(uint256 amount, bytes calldata proof)
        external
        returns (bool);
}

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112

library UQ112x112 {
    uint224 private constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

contract PrpConverter is ImmutableOwnable, Claimable {
    // The contract is supposed to run behind a proxy DELEGATECALLing it.
    // On upgrades, adjust `__gap` to match changes of the storage layout.
    // slither-disable-next-line shadowing-state unused-state
    uint256[50] private __gap;

    // solhint-disable var-name-mixedcase

    /// @notice Address of the $ZKP token contract
    address private immutable ZKP_TOKEN;

    /// @notice Address of the PantherPool contract
    address public immutable PANTHER_POOL;

    // solhint-enable var-name-mixedcase

    uint112 private prpReserve;
    uint112 private zkpReserve;
    uint32 private blockTimestampLast;

    bool private initialized;

    uint256 public pricePrpCumulativeLast;
    uint256 public priceZkpCumulativeLast;

    event Initialized(uint256 prpVirtualAmount, uint256 zkpAmount);
    event Sync(uint112 prpReserve, uint112 zkpReserve);

    constructor(
        address _owner,
        address zkpToken,
        address pantherPool
    ) ImmutableOwnable(_owner) {
        require(
            zkpToken != address(0) && pantherPool != address(0),
            ERR_ZERO_ADDRESS
        );

        ZKP_TOKEN = zkpToken;
        PANTHER_POOL = pantherPool;
    }

    modifier isInitialized() {
        require(initialized, ERR_ALREADY_INITIALIZED);
        _;
    }

    function initPool(uint256 prpVirtualAmount, uint256 zkpAmount)
        external
        onlyOwner
    {
        require(!initialized, ERR_ALREADY_INITIALIZED);

        uint256 zkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );
        require(zkpBalance >= zkpAmount, ERR_LOW_INIT_ZKP_BALANCE);

        initialized = true;

        _update(
            prpVirtualAmount,
            zkpAmount,
            uint112(prpVirtualAmount),
            uint112(zkpAmount)
        );

        emit Initialized(prpVirtualAmount, zkpAmount);
    }

    function updateZkpReserve() external isInitialized {
        uint256 zkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );

        (uint112 _prpReserve, uint112 _zkpReserve, ) = getReserves();

        if (zkpBalance <= _zkpReserve) return;

        uint256 zkpAmountIn = zkpBalance - _zkpReserve;

        uint256 prpAmountOut = getAmountOut(
            zkpAmountIn,
            _zkpReserve,
            _prpReserve
        );

        uint256 prpVirtualBalance = _prpReserve - prpAmountOut;

        _update(prpVirtualBalance, zkpBalance, _prpReserve, _zkpReserve);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(
            amountIn > 0 && reserveIn > 0 && reserveOut > 0,
            "PCL: Insufficient input"
        );
        require(reserveIn > 0 && reserveOut > 0, "PCL: Insufficient liquidity");

        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }

    function getReserves()
        public
        view
        returns (
            uint112 _prpReserve,
            uint112 _zkpReserve,
            uint32 _blockTimestampLast
        )
    {
        _prpReserve = prpReserve;
        _zkpReserve = zkpReserve;
        _blockTimestampLast = blockTimestampLast;
    }

    function convert(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _to,
        uint256 _deadline,
        bytes memory _proof
    ) external {
        require(_proof.length > 0, "PC: Invalid prrof");
        require(_deadline >= block.timestamp, "PC: Convert expired");
        require(_to != ZKP_TOKEN, "PC: Invalid receiver");

        (uint112 _prpReserve, uint112 _zkpReserve, ) = getReserves();

        require(_zkpReserve > 0, "PC: Insufficient liquidity");

        uint256 amountOut = getAmountOut(_amountIn, _prpReserve, _zkpReserve);

        require(amountOut >= _amountOutMin, "PC: Insufficient output");

        require(amountOut < _zkpReserve, "PC: Insufficient liquidity");
        require(
            IPantherPool(PANTHER_POOL).burnPrp(_amountIn, _proof),
            "PC: Prp burn failed"
        );

        TransferHelper.safeTransfer(ZKP_TOKEN, _to, amountOut);

        uint256 prpVirtualBalance = _prpReserve + _amountIn;
        uint256 zkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );

        require(
            prpVirtualBalance * zkpBalance >=
                uint256(_prpReserve) * _zkpReserve,
            "PCL: K"
        );

        _update(prpVirtualBalance, zkpBalance, _prpReserve, _zkpReserve);
    }

    function _update(
        uint256 prpVirtualBalance,
        uint256 zkpBalance,
        uint112 prpReserves,
        uint112 zkpReserves
    ) private {
        prpReserve = uint112(prpVirtualBalance);
        zkpReserve = uint112(zkpBalance);
        uint32 blockTimestamp = uint32(block.timestamp);

        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && zkpReserves != 0) {
            pricePrpCumulativeLast +=
                uint256(
                    UQ112x112.uqdiv(UQ112x112.encode(zkpReserves), prpReserves)
                ) *
                timeElapsed;

            priceZkpCumulativeLast +=
                uint256(
                    UQ112x112.uqdiv(UQ112x112.encode(prpReserves), zkpReserves)
                ) *
                timeElapsed;
        }

        emit Sync(prpReserve, zkpReserve);
    }

    /// @dev May be only called by the {OWNER}
    function rescueErc20(
        address token,
        address to,
        uint256 amount
    ) external {
        require(OWNER == msg.sender, ERR_UNAUTHORIZED);

        _claimErc20(token, to, amount);
    }
}
