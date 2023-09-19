// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity 0.8.16;
// TODO: add one contract per file

import "../protocol/interfaces/IPantherPoolV1.sol";
import { FIELD_SIZE } from "../protocol/crypto/SnarkConstants.sol";

import "../common/TransferHelper.sol";
import "../common/ImmutableOwnable.sol";
import "../common/Claimable.sol";

import "./errMsgs/PrpConverterErrMsgs.sol";

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

    /// @notice Address of the Vault contract
    address public immutable VAULT;

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
        address pantherPool,
        address vault
    ) ImmutableOwnable(_owner) {
        require(
            zkpToken != address(0) && pantherPool != address(0) && vault != address(0),
            ERR_ZERO_ADDRESS
        );

        ZKP_TOKEN = zkpToken;
        PANTHER_POOL = pantherPool;
        VAULT = vault;
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

        TransferHelper.safeIncreaseAllowance(ZKP_TOKEN,VAULT,zkpAmount);

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

        TransferHelper.safeIncreaseAllowance(ZKP_TOKEN,VAULT,zkpAmountIn);

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

    /// @param inputs[0] - extraInputsHash;
    /// @param inputs[1] - chargedAmountZkp;
    /// @param inputs[2] - createTime;
    /// @param inputs[3] - depositAmountPrp;
    /// @param inputs[4] - withdrawAmountPrp;
    /// @param inputs[5] - utxoCommitment;
    /// @param inputs[6] - zAssetScale;
    /// @param inputs[7] - zAccountUtxoInNullifier;
    /// @param inputs[8] - zAccountUtxoOutCommitment;
    /// @param inputs[9] - zNetworkChainId;
    /// @param inputs[10] - forestMerkleRoot;
    /// @param inputs[11] - saltHash;
    /// @param inputs[12] - magicalConstraint;
     
    function convert(
        uint256[] calldata inputs,
        bytes calldata privateMessages,
        SnarkProof memory proof,
        uint256 prpAmountIn,
        uint256 zkpAmountOutMin,
        uint256 cachedForestRootIndex
    ) external returns (uint256 firstUtxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are 
        // less than the field size

        // NOTE: This contract expects the Pool will check the createTime (inputs[2]) which 
        // acts as a deadline

        {
            uint256 extraInputsHash = inputs[0];
            bytes memory extraInp = abi.encodePacked(
                privateMessages,
                cachedForestRootIndex,
                prpAmountIn,
                zkpAmountOutMin
            );
            require(
                extraInputsHash == uint256(keccak256(extraInp)) % FIELD_SIZE,
                ERR_INVALID_EXTRA_INPUT_HASH
            );
        }
        
        (uint112 _prpReserve, uint112 _zkpReserve, ) = getReserves();

        require(_zkpReserve > 0, "PC: Insufficient liquidity");

        uint256 zkpAmountOutRounded;

        {
            uint256 zkpAmountOut = getAmountOut(prpAmountIn, _prpReserve, _zkpReserve);

            uint256 scale = 10 ** inputs[6];
            require(zkpAmountOut >= scale, 'PC: Too low liquidity');

            zkpAmountOutRounded = (zkpAmountOut / scale) * 10 ** scale;

            require(zkpAmountOutRounded >= zkpAmountOutMin, "PC: Insufficient output");
            require(zkpAmountOutRounded < _zkpReserve, "PC: Insufficient liquidity");
        }
  

       firstUtxoBusQueuePos = _createZAccountAndZAssetUtxos(inputs, proof, zkpAmountOutRounded, cachedForestRootIndex);

        uint256 prpVirtualBalance = _prpReserve + prpAmountIn;
        uint256 zkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );

        require(
            prpVirtualBalance * zkpBalance >=
                uint256(_prpReserve) * _zkpReserve,
            "PC: K"
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


    function _createZAccountAndZAssetUtxos(
        uint256[] calldata inputs,
        SnarkProof memory proof,
        uint256 amountOutRounded,
        uint256 cachedForestRootIndex
    ) private returns(uint256 firstUtxoBusQueuePos) {

        // Trusted contract - no reentrancy guard needed
        // pool contract triggers vault to transfer `amountOut` from prpConverter
        try  
        IPantherPoolV1(PANTHER_POOL).accountPrpConvertion(
            inputs,
            proof,
            amountOutRounded,
            cachedForestRootIndex
        )  returns (uint256 result)
        {
             firstUtxoBusQueuePos = result;
        } catch Error(string memory reason) {
            revert(reason);
        }
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
