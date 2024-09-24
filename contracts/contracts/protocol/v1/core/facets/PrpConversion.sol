// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity 0.8.19;

import "../storage/AppStorage.sol";
import "../storage/PrpConversionStorageGap.sol";

import "../../diamond/utils/Ownable.sol";
import "../../verifier/Verifier.sol";

import "./prpConversion/ConversionHandler.sol";
import "../utils/TransactionChargesHandler.sol";
import "../utils/TransactionNoteEmitter.sol";
import "../../../../common/Claimable.sol";

import "../libraries/UtxosInserter.sol";
import "../libraries/NullifierSpender.sol";
import "../libraries/PublicInputGuard.sol";
import "../libraries/ZAssetUtxoGenerator.sol";

contract PrpConversion is
    AppStorage,
    PrpConversionStorageGap,
    Ownable,
    Verifier,
    ConversionHandler,
    TransactionChargesHandler,
    TransactionNoteEmitter,
    Claimable
{
    using UtxosInserter for address;
    using TransferHelper for address;
    using PublicInputGuard for address;
    using TransactionOptions for uint32;
    using PublicInputGuard for uint256;
    using ZAssetUtxoGenerator for uint256;
    using NullifierSpender for mapping(bytes32 => uint256);

    address internal immutable PANTHER_TREES;

    bool public initialized;

    event Initialized(uint256 prpVirtualAmount, uint256 zkpAmount);

    constructor(
        address vault,
        address pantherTrees,
        address feeMaster,
        address zkpToken
    ) ConversionHandler(vault) TransactionChargesHandler(feeMaster, zkpToken) {
        PANTHER_TREES = pantherTrees;
    }

    function initPool(
        uint256 prpVirtualAmount,
        uint256 zkpAmount
    ) external onlyOwner {
        require(!initialized, ERR_ALREADY_INITIALIZED);

        uint256 zkpBalance = ZKP_TOKEN.safeBalanceOf(address(this));
        require(zkpBalance >= zkpAmount, ERR_LOW_INIT_ZKP_BALANCE);

        initialized = true;

        TransferHelper.safeIncreaseAllowance(ZKP_TOKEN, VAULT, zkpAmount);

        _update(prpVirtualAmount, zkpAmount);

        emit Initialized(prpVirtualAmount, zkpAmount);
    }

    function increaseZkpReserve() external {
        require(initialized, ERR_NOT_INITIALIZED);

        uint256 zkpBalance = TransferHelper.safeBalanceOf(
            ZKP_TOKEN,
            address(this)
        );

        (uint256 _prpReserve, uint256 _zkpReserve, ) = getReserves();

        if (zkpBalance <= _zkpReserve) return;

        uint256 zkpAmountIn = zkpBalance - _zkpReserve;

        uint256 prpAmountOut = getAmountOut(
            zkpAmountIn,
            _zkpReserve,
            _prpReserve
        );

        uint256 prpVirtualBalance = _prpReserve - prpAmountOut;

        _update(prpVirtualBalance, zkpBalance);
    }

    /// @notice Accounts prp conversion
    /// @dev It converts prp to zZkp. The msg.sender should approve pantherPool to transfer the
    /// ZKPs to the vault in order to create new zAsset utxo. In ideal case, the msg sender is prpConverter.
    /// This function also spend the old zAccount utxo and creates new one with decreased prp balance.
    /// @param inputs The public input parameters to be passed to verifier
    /// (refer to MainPublicSignals.sol).
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// This data is used to spend the newly created utxo.
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param zkpAmountOutMin Minimum zZkp to receive.
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    function convert(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 zkpAmountOutMin,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external returns (uint256 firstUtxoBusQueuePos) {
        _validateExtraInputs(
            inputs[PRP_CONVERSION_EXTRA_INPUT_HASH_IND],
            transactionOptions,
            zkpAmountOutMin,
            paymasterCompensation,
            privateMessages
        );

        _checkNonZeroPublicInputs(inputs);

        {
            uint256 creationTime = inputs[
                PRP_CONVERSION_UTXO_OUT_CREATE_TIME_IND
            ];
            creationTime.validateCreationTime(maxBlockTimeOffset);

            uint256 zNetworkChainId = inputs[
                PRP_CONVERSION_ZNETWORK_CHAIN_ID_IND
            ];
            zNetworkChainId.validateChainId();
        }

        _sanitizePrivateMessage(privateMessages, TT_PRP_CONVERSION);

        isSpent.validateAndSpendNullifier(
            inputs[PRP_CONVERSION_ZACCOUNT_UTXO_IN_NULLIFIER_IND]
        );

        uint256 zkpAmountOutScaled = _processConversion(
            ZKP_TOKEN,
            zkpAmountOutMin,
            inputs
        );

        bytes32 zAssetUtxoOutCommitment = zkpAmountOutScaled
            .generateZAssetUtxoCommitment(
                inputs[PRP_CONVERSION_UTXO_COMMITMENT_PRIVATE_PART_IND]
            );

        {
            uint160 circuitId = circuitIds[TT_PRP_CONVERSION];
            verifyOrRevert(circuitId, inputs, proof);
        }

        {
            uint96 miningReward = accountFeesAndReturnMiningReward(
                feeMasterDebt,
                inputs,
                paymasterCompensation,
                TT_PRP_CONVERSION
            );

            uint32 zAccountUtxoQueueId;
            uint8 zAccountUtxoIndexInQueue;

            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                firstUtxoBusQueuePos
            ) = PANTHER_TREES.insertPrpConversionUtxos(
                inputs,
                zAssetUtxoOutCommitment,
                transactionOptions,
                miningReward
            );

            _emitPrpConversionNote(
                inputs,
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zkpAmountOutScaled,
                privateMessages
            );
        }
    }

    function _checkNonZeroPublicInputs(uint256[] calldata inputs) private pure {
        inputs[PRP_CONVERSION_ZASSET_SCALE_IND].validateNonZero(ERR_ZERO_SCALE);

        inputs[PRP_CONVERSION_SALT_HASH_IND].validateNonZero(
            ERR_ZERO_SALT_HASH
        );

        inputs[PRP_CONVERSION_MAGICAL_CONSTRAINT_IND].validateNonZero(
            ERR_ZERO_MAGIC_CONSTR
        );

        inputs[PRP_CONVERSION_ZASSET_SCALE_IND].validateNonZero(
            ERR_ZERO_ZASSET_SCALE
        );
    }

    function _validateExtraInputs(
        uint256 extraInputsHash,
        uint32 transactionOptions,
        uint96 zkpAmountOutMin,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) private pure {
        bytes memory extraInp = abi.encodePacked(
            transactionOptions,
            zkpAmountOutMin,
            paymasterCompensation,
            privateMessages
        );
        extraInputsHash.validateExtraInputHash(extraInp);
    }

    /// @dev May be only called by the {OWNER}
    function rescueErc20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        _claimErc20(token, to, amount);
    }
}
