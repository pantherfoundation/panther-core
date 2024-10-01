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

/**
 * @title PrpConversion
 * @notice Handles the conversion of PRPs to zZKP tokens.
 * @dev This contract manages the conversion process, including the initialization of reserves,
 * adjusting ZKP reserves, and processing the conversion of PRP to zZKP.
 */
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

    /**
     * @notice Initializes the conversion pool with specified amounts of PRP and ZKP tokens.
     * @param prpVirtualAmount The virtual amount of PRP to initialize.
     * @param zkpAmount The amount of ZKP tokens required for the initialization.
     * @dev This function can only be called by the contract owner. ZKP tokens must be transferred to
     * this contract prior to initialization.
     * It also increases the Vault’s allowance to allow it to transfer ZKP tokens from this contract
     * during conversion operations.
     */
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

    /**
     * @notice Increases the ZKP reserve based on the available balance.
     * @dev This function can be called only after the contract has been initialized.
     * It checks the current balance of ZKP tokens and updates the reserves if there
     * are additional tokens beyond the current reserve.
     * It also increases the Vault’s allowance to allow it to transfer ZKP tokens from this contract
     * during conversion operations.
     */
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

    /**
     * @notice Converts PRP tokens to zZKP tokens.
     * @param inputs The public input parameters to be passed to the verifier.
     * (see `PrpConversionPublicSignals.sol`).
     * @param proof The zero knowledge proof
     * @param transactionOptions Options for the transaction, encoded as a 17-bit number.
     * @param zkpAmountOutMin The minimum amount of zZKP tokens to receive from the conversion.
     * @param paymasterCompensation Compensation for the paymaster.
     * @param privateMessages Private message containing zAccount utxo data.
     * @return firstUtxoBusQueuePos Position in the UTXO bus queue for the first UTXO.
     * @dev Handles the spending of old zAccount UTXOs and creates new ones with the
     * updated PRP balance.
     * The user can choose whether the UTXO should be added quickly via the taxi tree
     * or slowly via the bus tree. The transactionOptions param defines the method used (further
     * details can be found in the `TransactionOptions.sol` library)
     */
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

    /**
     * @dev Validates that the public inputs are non-zero.
     * @param inputs The public input parameters to check.
     */
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

    /**
     * @notice Validates extra inputs
     * @dev Checks the provided inputs against their expected hash to ensure data integrity.
     * @param extraInputsHash The hash of the extra inputs to validate.
     * @param transactionOptions A 17-bit number where the 8 LSB defines the cachedForestRootIndex,
     * the 1 MSB enables/disables the taxi tree, and other bits are reserved.
     * @param zkpAmountOutMin Minimum zZKP tokens to receive.
     * @param paymasterCompensation Compensation for the paymaster.
     * @param privateMessages Private message of the user.
     * (see `TransactionNoteEmitter.sol`).
     */
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

    /**
     * @notice Rescues ERC20 tokens from the contract.
     * @param token The address of the ERC20 token to rescue.
     * @param to The address to send the rescued tokens to.
     * @param amount The amount of tokens to rescue.
     * @dev This function can only be called by the contract owner.
     */
    function rescueErc20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        _claimErc20(token, to, amount);
    }
}
