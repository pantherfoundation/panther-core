// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity 0.8.19;

import "./interfaces/IPantherPoolV1.sol";
import { FIELD_SIZE } from "../../common/crypto/SnarkConstants.sol";

import "../../common/TransferHelper.sol";
import "../../common/ImmutableOwnable.sol";
import "../../common/Claimable.sol";
import "../../common/UtilsLib.sol";

import "./errMsgs/PrpConverterErrMsgs.sol";

contract PrpConverter is ImmutableOwnable, Claimable {
    // The contract is supposed to run behind a proxy DELEGATECALLing it.
    // On upgrades, adjust `__gap` to match changes of the storage layout.
    // slither-disable-next-line shadowing-state unused-state
    uint256[50] private __gap;

    /// @notice Address of the $ZKP token contract
    address public immutable ZKP_TOKEN;

    /// @notice Address of the PantherPool contract
    address public immutable PANTHER_POOL;

    /// @notice Address of the Vault contract
    address public immutable VAULT;

    uint64 private prpReserve;
    uint96 private zkpReserve;
    uint32 private blockTimestampLast;

    bool public initialized;

    event Initialized(uint256 prpVirtualAmount, uint256 zkpAmount);
    event Sync(uint112 prpReserve, uint112 zkpReserve);

    constructor(
        address _owner,
        address zkpToken,
        address pantherPool,
        address vault
    ) ImmutableOwnable(_owner) {
        require(
            zkpToken != address(0) &&
                pantherPool != address(0) &&
                vault != address(0),
            ERR_ZERO_ADDRESS
        );

        ZKP_TOKEN = zkpToken;
        PANTHER_POOL = pantherPool;
        VAULT = vault;
    }

    function initPool(
        uint256 prpVirtualAmount,
        uint256 zkpAmount
    ) external onlyOwner {
        require(!initialized, ERR_ALREADY_INITIALIZED);

        uint256 zkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );
        require(zkpBalance >= zkpAmount, ERR_LOW_INIT_ZKP_BALANCE);

        initialized = true;

        TransferHelper.safeIncreaseAllowance(ZKP_TOKEN, VAULT, zkpAmount);

        _update(prpVirtualAmount, zkpAmount);

        emit Initialized(prpVirtualAmount, zkpAmount);
    }

    function updateZkpReserve() external {
        require(initialized, ERR_NOT_INITIALIZED);

        uint256 zkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );

        (uint256 _prpReserve, uint256 _zkpReserve, ) = getReserves();

        if (zkpBalance <= _zkpReserve) return;

        uint256 zkpAmountIn = zkpBalance - _zkpReserve;

        TransferHelper.safeIncreaseAllowance(ZKP_TOKEN, VAULT, zkpAmountIn);

        uint256 prpAmountOut = getAmountOut(
            zkpAmountIn,
            _zkpReserve,
            _prpReserve
        );

        uint256 prpVirtualBalance = _prpReserve - prpAmountOut;

        _update(prpVirtualBalance, zkpBalance);
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

    /// @notice Accounts prp conversion
    /// @dev It converts prp to zZkp. The msg.sender should approve pantherPool to transfer the
    /// ZKPs to the vault in order to create new zAsset utxo. In ideal case, the msg sender is prpConverter.
    /// This function also spend the old zAccount utxo and creates new one with decreased prp balance.
    /// @param inputs The public input parameters to be passed to verifier.
    /// @param inputs[0]  - extraInputsHash;
    /// @param inputs[1]  - chargedAmountZkp;
    /// @param inputs[2]  - createTime;
    /// @param inputs[3]  - depositAmountPrp;
    /// @param inputs[4]  - withdrawAmountPrp;
    /// @param inputs[5]  - utxoCommitmentPrivatePart;
    /// @param inputs[6]  - utxoSpendPubKeyX
    /// @param inputs[7]  - utxoSpendPubKeyY
    /// @param inputs[8]  - zAssetScale;
    /// @param inputs[9]  - zAccountUtxoInNullifier;
    /// @param inputs[10] - zAccountUtxoOutCommitment;
    /// @param inputs[11] - zNetworkChainId;
    /// @param inputs[12] - forestMerkleRoot;
    /// @param inputs[13] - saltHash;
    /// @param inputs[14] - magicalConstraint;
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// This data is used to spend the newly created utxo.
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param zkpAmountOutMin Minimum zZkp to receive.
    /// @param cachedForestRootIndex forest merkle root index. 0 means the most updated root.
    function convert(
        uint256[] calldata inputs,
        bytes calldata privateMessages,
        SnarkProof memory proof,
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
                zkpAmountOutMin
            );
            require(
                extraInputsHash == uint256(keccak256(extraInp)) % FIELD_SIZE,
                ERR_INVALID_EXTRA_INPUT_HASH
            );
        }

        {
            // this function is not supposed to add (aka deposit) prp to zAccount
            uint256 depositAmountPrp = inputs[3];
            require(depositAmountPrp == 0, ERR_NON_ZERO_DEPOSIT_AMOUNT_PRP);
        }

        (uint256 _prpReserve, uint256 _zkpReserve, ) = getReserves();

        require(_zkpReserve > 0, ERR_INSUFFICIENT_LIQUIDITY);

        uint256 zkpAmountOutRounded;
        // amount to be withdrawn from zAccount UTXO and added to the converter's prpVirtualBalance
        uint256 withdrawAmountPrp = inputs[4];

        {
            uint256 zkpAmountOut = getAmountOut(
                withdrawAmountPrp,
                _prpReserve,
                _zkpReserve
            );

            uint256 scale = inputs[8];
            require(zkpAmountOut >= scale, ERR_INSUFFICIENT_AMOUNT_OUT);
            require(zkpAmountOut >= zkpAmountOutMin, ERR_LOW_AMOUNT_OUT);

            unchecked {
                // rounding the amount (leaving the changes in the contract)
                zkpAmountOutRounded = (zkpAmountOut / scale) * scale;
            }

            require(zkpAmountOutRounded < _zkpReserve, ERR_LOW_LIQUIDITY);
        }

        firstUtxoBusQueuePos = _createZzkpUtxoAndSpendPrpUtxo(
            inputs,
            proof,
            privateMessages,
            zkpAmountOutRounded,
            cachedForestRootIndex
        );

        uint256 prpVirtualBalance = _prpReserve + withdrawAmountPrp;
        uint256 zkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );

        require(
            prpVirtualBalance * zkpBalance >=
                uint256(_prpReserve) * _zkpReserve,
            ERR_LOW_CONSTANT_PRODUCT
        );

        _update(prpVirtualBalance, zkpBalance);
    }

    function _update(uint256 prpVirtualBalance, uint256 zkpBalance) private {
        prpReserve = UtilsLib.safe64(prpVirtualBalance);
        zkpReserve = UtilsLib.safe96(zkpBalance);
        blockTimestampLast = UtilsLib.safe32(block.timestamp);

        emit Sync(prpReserve, zkpReserve);
    }

    function _createZzkpUtxoAndSpendPrpUtxo(
        uint256[] calldata inputs,
        SnarkProof memory proof,
        bytes memory privateMessages,
        uint256 amountOutRounded,
        uint256 cachedForestRootIndex
    ) private returns (uint256 firstUtxoBusQueuePos) {
        // Trusted contract - no reentrancy guard needed
        // pool contract triggers vault to transfer `amountOut` from prpConverter
        try
            IPantherPoolV1(PANTHER_POOL).createZzkpUtxoAndSpendPrpUtxo(
                inputs,
                proof,
                privateMessages,
                amountOutRounded,
                cachedForestRootIndex
            )
        returns (uint256 result) {
            firstUtxoBusQueuePos = result;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    /// @dev May be only called by the {OWNER}
    function rescueErc20(address token, address to, uint256 amount) external {
        require(OWNER == msg.sender, ERR_UNAUTHORIZED);

        _claimErc20(token, to, amount);
    }
}
