// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
pragma solidity ^0.8.19;

import "./interfaces/IVerifier.sol";
import "./interfaces/IPantherPoolV1.sol";

import "./errMsgs/PantherPoolV1ErrMsgs.sol";

import "./pantherForest/PantherForest.sol";
import "./pantherPool/TransactionNoteEmitter.sol";
import "./pantherPool/TransactionChargesHandler.sol";
import "./pantherPool/DepositAndWithdrawalHandler.sol";
import "./pantherPool/UtxosInserter.sol";
import "./pantherPool/TransactionTypes.sol";
import "./pantherPool/ZAssetUtxoGeneratorLib.sol";
import "./pantherPool/ZSwapLib.sol";

import "../../common/UtilsLib.sol";
import "../../common/NonReentrant.sol";

/**
 * @title PantherPool
 * @author Pantherprotocol Contributors
 * @notice Multi-Asset Shielded Pool main contract v1
 * @dev Version 1 of the Panther Protocol Multi-Asset Shielded Pool (MASP), empowers users
 * to create z-Account and z-Asset UTXOs for heightened privacy and security.
 * The z-Account serves as a user's identity, containing essential information like
 * identification and cryptographic keys. Users can also create z-assets UTXOs, as well as
 * transfer assets between z-Asset and z-Account UTXOs. Notably, each user is limited to one
 * z-Account UTXO at a time.
 * Furthermore, this version introduces new functionalities of Panther Rewards Points (PRP).
 * users can claim (i.e. adding PRP to z-Account UTXO) and convert (i.e. burning PRP from
 * z-Account UTXO and creating a new z-Asset UTXO) into zKp tokens.
 * The contract manages asset locking/unlocking and transfers, covering ERC-20, ERC-721, and
 * ERC-1155 tokens, via the Vault smart contract for secure deposit and withdrawal.
 * All z-Account and z-Asset UTXO creations utilize zero-knowledge proof methods, with the
 * verification keys stored on-chain. Users must provide proofs and public inputs to the
 * contract, which verifies and dispatches UTXOs to the BusTree for eventual minting into
 * the Merkle Tree by miners.
 */
contract PantherPoolV1 is
    PantherForest,
    TransactionNoteEmitter,
    UtxosInserter,
    NonReentrant,
    TransactionChargesHandler,
    DepositAndWithdrawalHandler,
    IPantherPoolV1
{
    using ZAssetUtxoGeneratorLib for uint256;
    using TransactionOptions for uint32;
    using TransactionTypes for uint16;
    using PluginDataDecoderLib for bytes;
    using ZSwapLib for address;
    using VaultLib for address;
    using UtilsLib for uint256;

    // initialGap - PantherForest slots - CachedRoots slots => 500 - 22 - 25
    // slither-disable-next-line shadowing-state unused-state
    uint256[450] private __gap;

    address public immutable VERIFIER;
    address public immutable ZACCOUNT_REGISTRY;
    address public immutable PRP_VOUCHER_GRANTOR;
    address public immutable PRP_CONVERTER;
    address public immutable STATIC_TREE;
    address public immutable VAULT;

    mapping(address => bool) public vaultAssetUnlockers;

    // TODO: to be removed in production
    uint256[13] private __circuiteIdsGap;

    // @notice Seen (i.e. spent) commitment nullifiers
    // nullifier hash => spent
    mapping(bytes32 => bool) public isSpent;

    uint96 public accountedRewards;
    uint96 public kycReward;
    // max difference between the given utxo create/spend time and now
    uint32 public maxTimeDelta;

    // kytMessageHash => blockNumber
    uint256 private seenKytMessageHashesGap;
    // TODO:to be deleted
    // left for storage compatibility of the "testnet" version, must be deleted in the prod version
    uint256 private _feeMasterDebtGap;
    // transaction type => circuit id
    mapping(uint16 => uint160) public circuitIds;

    // plugin address to boolean
    mapping(address => bool) public zSwapPlugins;

    event CircuitIdUpdated(uint16 txType, uint160 newId);
    event ZSwapPluginUpdated(address plugin, bool status);
    event KycRewardUpdated(uint256 newReward);
    event MaxTimeDeltaUpdated(uint256 newMaxTimeDelta);
    event VaultAssetUnlockerUpdated(address newAssetUnlocker, bool status);

    constructor(
        address _owner,
        address zkpToken,
        ForestTrees memory forestTrees,
        address staticTree,
        address vault,
        address zAccountRegistry,
        address prpVoucherGrantor,
        address prpConverter,
        address feeMaster,
        address verifier
    )
        PantherForest(_owner, forestTrees)
        UtxosInserter(forestTrees.busTree, forestTrees.taxiTree)
        TransactionChargesHandler(zkpToken, feeMaster)
    {
        require(
            staticTree != address(0) &&
                verifier != address(0) &&
                zAccountRegistry != address(0) &&
                prpVoucherGrantor != address(0) &&
                prpConverter != address(0),
            ERR_INIT
        );

        STATIC_TREE = staticTree;
        VERIFIER = verifier;
        ZACCOUNT_REGISTRY = zAccountRegistry;
        PRP_VOUCHER_GRANTOR = prpVoucherGrantor;
        PRP_CONVERTER = prpConverter;
        VAULT = vault;
    }

    // function updateVaultAssetUnlocker(
    //     address _unlocker,
    //     bool _status
    // ) external onlyOwner {
    //     vaultAssetUnlockers[_unlocker] = _status;

    //     emit VaultAssetUnlockerUpdated(_unlocker, _status);
    // }

    function updatePluginStatus(
        address plugin,
        bool status
    ) external onlyOwner {
        zSwapPlugins[plugin] = status;

        emit ZSwapPluginUpdated(plugin, status);
    }

    function updateCircuitId(
        uint16 txType,
        uint160 circuitId
    ) external onlyOwner {
        circuitIds[txType] = circuitId;

        emit CircuitIdUpdated(txType, circuitId);
    }

    function updateMaxTimeDelta(uint32 _maxTimeDelta) external onlyOwner {
        maxTimeDelta = _maxTimeDelta;

        emit MaxTimeDeltaUpdated(_maxTimeDelta);
    }

    function unlockAssetFromVault(LockData calldata data) external {
        require(vaultAssetUnlockers[msg.sender], ERR_UNAUTHORIZED);
        VAULT.unlockAsset(data);
    }

    /// @notice Creates zAccount utxo
    /// @dev It can be executed only by zAccountsRegistry contract.
    /// @param inputs The public input parameters to be passed to verifier
    /// (refer to ZAccountActivationPublicSignals.sol).
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint16 transactionType,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external nonReentrant returns (uint256 utxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(msg.sender == ZACCOUNT_REGISTRY, ERR_UNAUTHORIZED);
        uint160 zAccountRegistrationCircuitId = _getCircuitIdOrRevert(
            TT_ZACCOUNT_ACTIVATION
        );

        _validateNonZero(
            inputs[ZACCOUNT_ACTIVATION_SALT_HASH_IND],
            ERR_ZERO_SALT_HASH
        );
        _validateNonZero(
            inputs[ZACCOUNT_ACTIVATION_MAGICAL_CONSTRAINT_IND],
            ERR_ZERO_MAGIC_CONSTR
        );
        _validateNonZero(
            inputs[ZACCOUNT_ACTIVATION_NULLIFIER_ZONE_IND],
            ERR_ZERO_NULLIFIER
        );
        _validateNonZero(
            inputs[ZACCOUNT_ACTIVATION_UTXO_OUT_COMMITMENT_IND],
            ERR_ZERO_ZACCOUNT_COMMIT
        );
        _validateNonZero(
            inputs[ZACCOUNT_ACTIVATION_KYC_SIGNED_MESSAGE_HASH_IND],
            ERR_ZERO_KYC_MSG_HASH
        );

        _validateStaticRoot(inputs[ZACCOUNT_ACTIVATION_STATIC_MERKLE_ROOT_IND]);

        _validateCreationTime(
            inputs[ZACCOUNT_ACTIVATION_UTXO_OUT_CREATE_TIME_IND]
        );

        _sanitizePrivateMessage(privateMessages, TT_ZACCOUNT_ACTIVATION);

        _validateCachedForestRoot(
            inputs[ZACCOUNT_ACTIVATION_FOREST_MERKLE_ROOT_IND],
            transactionOptions.cachedForestRootIndex()
        );

        _verifyProof(zAccountRegistrationCircuitId, inputs, proof);

        uint96 miningReward = accountFeesAndReturnMiningReward(
            inputs,
            paymasterCompensation,
            transactionType
        );

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            utxoBusQueuePos
        ) = _insertZAccountActivationUtxos(
            inputs,
            transactionOptions,
            miningReward
        );

        _emitZAccountActivationNote(
            inputs,
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            transactionType,
            privateMessages
        );
    }

    /// @notice Accounts prp to zAccount
    /// @dev It spends the old zAccount utxo and create a new one with increased
    /// prp balance. It can be executed only be prpVoucherGrantor.
    /// @param inputs The public input parameters to be passed to verifier
    /// (refer to PrpClaimPublicSignals.sol).
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// This data is used to spend the newly created utxo.
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    function accountPrp(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external nonReentrant returns (uint256 utxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        // Note: This contract expects the PrpVoucherGrantor to check the following inputs:
        // input[0], input[3], input[4],

        require(msg.sender == PRP_VOUCHER_GRANTOR, ERR_UNAUTHORIZED);
        uint160 prpAccountingCircuitId = _getCircuitIdOrRevert(TT_PRP_CLAIM);

        _validateCreationTime(inputs[PRP_CLAIM_UTXO_OUT_CREATE_TIME_IND]);

        _validateStaticRoot(inputs[PRP_CLAIM_STATIC_MERKLE_ROOT_IND]);

        _sanitizePrivateMessage(privateMessages, TT_PRP_CLAIM);

        _validateNonZero(
            inputs[PRP_CLAIM_ZACCOUNT_UTXO_OUT_COMMITMENT_IND],
            ERR_ZERO_ZACCOUNT_COMMIT
        );

        _validateAndSpendNullifier(
            inputs[PRP_CLAIM_ZACCOUNT_UTXO_IN_NULLIFIER_IND]
        );

        _validateZNetworkChainId(inputs[PRP_CLAIM_ZNETWORK_CHAIN_ID_IND]);

        _validateCachedForestRoot(
            inputs[PRP_CLAIM_FOREST_MERKLE_ROOT_IND],
            transactionOptions.cachedForestRootIndex()
        );

        _verifyProof(prpAccountingCircuitId, inputs, proof);

        uint96 miningReward = accountFeesAndReturnMiningReward(
            inputs,
            paymasterCompensation,
            TT_PRP_CLAIM
        );

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;
        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            utxoBusQueuePos
        ) = _insertPrpClaimUtxo(inputs, transactionOptions, miningReward);

        _emitPrpClaimNote(
            inputs,
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            privateMessages
        );
    }

    /// @notice Accounts prp conversion
    /// @dev It converts prp to zZkp. The msg.sender should approve pantherPool to transfer the
    /// ZKPs to the vault in order to create new zAsset utxo. In ideal case, the msg sender is prpConverter.
    /// This function also spend the old zAccount utxo and creates new one with decreased prp balance.
    /// @param inputs The public input parameters to be passed to verifier
    /// (refer to PrpConversionPublicSignals.sol).
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// This data is used to spend the newly created utxo.
    /// @param zkpAmountRounded The zkp amount to be locked in the vault, rounded by zAsset scale factor.
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    function createZzkpUtxoAndSpendPrpUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 zkpAmountRounded,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external nonReentrant returns (uint256 zAccountUtxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(msg.sender == PRP_CONVERTER, ERR_UNAUTHORIZED);
        uint160 prpAccountConversionCircuitId = _getCircuitIdOrRevert(
            TT_PRP_CONVERSION
        );

        _validateNonZero(
            inputs[PRP_CONVERSION_SALT_HASH_IND],
            ERR_ZERO_SALT_HASH
        );
        _validateNonZero(
            inputs[PRP_CONVERSION_MAGICAL_CONSTRAINT_IND],
            ERR_ZERO_MAGIC_CONSTR
        );

        _validateStaticRoot(inputs[PRP_CONVERSION_STATIC_MERKLE_ROOT_IND]);

        _validateZNetworkChainId(inputs[PRP_CONVERSION_ZNETWORK_CHAIN_ID_IND]);

        _validateCreationTime(inputs[PRP_CONVERSION_UTXO_OUT_CREATE_TIME_IND]);

        _sanitizePrivateMessage(privateMessages, TT_PRP_CONVERSION);

        _validateCachedForestRoot(
            inputs[PRP_CONVERSION_FOREST_MERKLE_ROOT_IND],
            transactionOptions.cachedForestRootIndex()
        );

        require(
            inputs[PRP_CONVERSION_DEPOSIT_PRP_AMOUNT_IND] == 0 &&
                inputs[PRP_CONVERSION_WITHDRAW_PRP_AMOUNT_IND] <=
                MAX_PRP_AMOUNT,
            ERR_TOO_LARGE_PRP_AMOUNT
        );

        _validateAndSpendNullifier(
            inputs[PRP_CONVERSION_ZACCOUNT_UTXO_IN_NULLIFIER_IND]
        );

        _verifyProof(prpAccountConversionCircuitId, inputs, proof);

        uint256 zkpAmountScaled = zkpAmountRounded /
            inputs[PRP_CONVERSION_ZASSET_SCALE_IND];

        bytes32 zAssetUtxoOutCommitment = zkpAmountScaled
            .generateZAssetUtxoCommitment(
                inputs[PRP_CONVERSION_UTXO_COMMITMENT_PRIVATE_PART_IND]
            );

        uint96 miningReward = accountFeesAndReturnMiningReward(
            inputs,
            paymasterCompensation,
            TT_PRP_CONVERSION
        );

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;
        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _insertPrpConversionUtxos(
            inputs,
            zAssetUtxoOutCommitment,
            transactionOptions,
            miningReward
        );

        _lockZkp(msg.sender, zkpAmountRounded);

        _emitPrpConversionNote(
            inputs,
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zkpAmountScaled,
            privateMessages
        );
    }

    /// @param inputs The public input parameters to be passed to verifier
    /// (refer to MainPublicSignals.sol).
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount and zAssets utxo
    /// data.
    /// @param tokenType One of the numbers 0, 1, 2, 255 which determines ERC20, ERC721,
    /// ERC1155, and Native token respectively.
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    function main(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint8 tokenType,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external payable nonReentrant returns (uint256 zAccountUtxoBusQueuePos) {
        // The content of data escrow encrypted messages are checked by the circuit

        uint160 mainCircuitId = _getCircuitIdOrRevert(TT_MAIN_TRANSACTION);

        _validateNonZero(inputs[MAIN_SALT_HASH_IND], ERR_ZERO_SALT_HASH);
        _validateNonZero(
            inputs[MAIN_MAGICAL_CONSTRAINT_IND],
            ERR_ZERO_MAGIC_CONSTR
        );

        _validateZNetworkChainId(inputs[MAIN_ZNETWORK_CHAIN_ID_IND]);
        {
            bytes memory extraInp = abi.encodePacked(
                transactionOptions,
                tokenType,
                paymasterCompensation,
                privateMessages
            );

            _validateExtraInputHash(
                inputs[MAIN_EXTRA_INPUT_HASH_IND],
                extraInp
            );
        }

        _validateStaticRoot(inputs[MAIN_STATIC_MERKLE_ROOT_IND]);

        _validateNonZero(
            inputs[MAIN_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND],
            ERR_ZERO_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
        );

        _validateNonZero(
            inputs[MAIN_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND],
            ERR_ZERO_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
        );

        _sanitizePrivateMessage(privateMessages, TT_MAIN_TRANSACTION);

        _validateCreationTime(inputs[MAIN_UTXO_OUT_CREATE_TIME_IND]);

        _validateSpendTime(inputs[MAIN_SPEND_TIME_IND]);

        _validateAndSpendNullifier(inputs[MAIN_ZASSET_UTXO_IN_NULLIFIER_1_IND]);
        _validateAndSpendNullifier(inputs[MAIN_ZASSET_UTXO_IN_NULLIFIER_2_IND]);
        _validateAndSpendNullifier(inputs[MAIN_ZACCOUNT_UTXO_IN_NULLIFIER_IND]);

        uint16 transactionType = TransactionTypes.generateMainTxType(inputs);

        (
            uint96 protocolFee,
            uint96 miningReward
        ) = accountFeesAndReturnProtocolFeeAndMiningReward(
                inputs,
                paymasterCompensation,
                transactionType
            );

        if (transactionType.isInternal()) {
            require(inputs[MAIN_TOKEN_IND] == 0, ERR_NON_ZERO_TOKEN);
        } else {
            // depost and/or withdraw tx
            // NOTE: This contract expects the Vault will check the token (inputs[4]) to
            // be non-zero only if the tokenType is not native.
            _processDepositAndWithdraw(
                inputs,
                tokenType,
                transactionType,
                protocolFee
            );
        }

        _validateCachedForestRoot(
            inputs[MAIN_FOREST_MERKLE_ROOT_IND],
            transactionOptions.cachedForestRootIndex()
        );

        _verifyProof(mainCircuitId, inputs, proof);

        {
            uint32 zAccountUtxoQueueId;
            uint8 zAccountUtxoIndexInQueue;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _insertMainUtxos(inputs, transactionOptions, miningReward);

            _emitMainNote(
                inputs,
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                transactionType,
                privateMessages
            );
        }
    }

    /// @param inputs The public input parameters to be passed to verifier
    /// (refer to MainPublicSignals.sol).
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    /// @param swapData The address of plugin that manages the swap proccess
    /// @param privateMessages the private message that contains zAccount and zAssets utxo
    /// data.
    function swapZAsset(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes memory swapData,
        bytes calldata privateMessages
    ) external returns (uint256 zAccountUtxoBusQueuePos) {
        uint160 zSwapCircuitId = _getCircuitIdOrRevert(TT_ZSWAP);

        {
            uint256 extraInputsHash = inputs[ZSWAP_EXTRA_INPUTS_HASH_IND];
            bytes memory extraInp = abi.encodePacked(
                transactionOptions,
                paymasterCompensation,
                swapData,
                privateMessages
            );
            require(
                extraInputsHash == uint256(keccak256(extraInp)) % FIELD_SIZE,
                "Invadlid hash"
            );
        }

        _validateNonZero(inputs[ZSWAP_SALT_HASH_IND], ERR_ZERO_SALT_HASH);
        _validateNonZero(
            inputs[ZSWAP_MAGICAL_CONSTRAINT_IND],
            ERR_ZERO_MAGIC_CONSTR
        );

        _validateZNetworkChainId(inputs[ZSWAP_ZNETWORK_CHAIN_ID_IND]);

        // TODO: extend it to sanitize the message
        // _sanitizePrivateMessage(privateMessages, TT_ZSWAP);

        _validateCreationTime(inputs[ZSWAP_UTXO_OUT_CREATE_TIME_IND]);

        _validateSpendTime(inputs[ZSWAP_SPEND_TIME_IND]);

        _validateAndSpendNullifier(
            inputs[ZSWAP_ZASSET_UTXO_IN_NULLIFIER_1_IND]
        );
        _validateAndSpendNullifier(
            inputs[ZSWAP_ZASSET_UTXO_IN_NULLIFIER_2_IND]
        );
        _validateAndSpendNullifier(
            inputs[ZSWAP_ZACCOUNT_UTXO_IN_NULLIFIER_IND]
        );

        _validateCachedForestRoot(
            inputs[ZSWAP_FOREST_MERKLE_ROOT_IND],
            transactionOptions.cachedForestRootIndex()
        );

        _validateVaultAddress(
            VAULT,
            inputs[ZSWAP_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER_IND]
        );
        _validateVaultAddress(
            VAULT,
            inputs[ZSWAP_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER_IND]
        );

        _verifyProof(zSwapCircuitId, inputs, proof);

        {
            (
                bytes32[2] memory zAssetUtxos,
                uint256 zAssetAmountScaled
            ) = _getKnownPluginOrRevert(swapData).processSwap(swapData, inputs);

            uint96 miningReward = accountFeesAndReturnMiningReward(
                inputs,
                paymasterCompensation,
                TT_ZSWAP
            );

            uint32 zAccountUtxoQueueId;
            uint8 zAccountUtxoIndexInQueue;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _insertZSwapUtxos(
                inputs,
                zAssetUtxos,
                transactionOptions,
                miningReward
            );
            _emitZSwapNote(
                inputs,
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAssetAmountScaled,
                privateMessages
            );
        }
    }

    function _getCircuitIdOrRevert(
        uint16 txType
    ) private view returns (uint160 circuitId) {
        circuitId = circuitIds[txType];
        require(circuitId != 0, ERR_UNDEFINED_CIRCUIT);
    }

    function _getKnownPluginOrRevert(
        bytes memory swapData
    ) private view returns (address _plugin) {
        _plugin = swapData.extractPluginAddress();
        require(zSwapPlugins[_plugin], ERR_UNKNOWN_PLUGIN);
    }

    function _verifyProof(
        uint160 circuitId,
        uint256[] calldata inputs,
        SnarkProof calldata proof
    ) private view {
        // Trusted contract - no reentrancy guard needed
        require(
            IVerifier(VERIFIER).verify(circuitId, inputs, proof),
            ERR_FAILED_ZK_PROOF
        );
    }

    function _getVault()
        internal
        view
        override(DepositAndWithdrawalHandler, TransactionChargesHandler)
        returns (address)
    {
        return VAULT;
    }

    function _validateAndSpendNullifier(uint256 nullifier) private {
        bytes32 _nullifier = bytes32(nullifier);

        require(_nullifier > 0, ERR_ZERO_NULLIFIER);
        require(!isSpent[_nullifier], ERR_SPENT_NULLIFIER);

        isSpent[_nullifier] = true;
    }

    function _validateZNetworkChainId(uint256 zNetworkChainId) private view {
        require(zNetworkChainId == block.chainid, ERR_INVALID_CHAIN_ID);
    }

    function _validateCreationTime(uint256 creationTime) private view {
        // Must be less than 32 bits and NOT in the past
        uint32 creationTimeSafe32 = UtilsLib.safe32(creationTime);

        require(
            creationTimeSafe32 >= block.timestamp &&
                (maxTimeDelta == 0 ||
                    creationTimeSafe32 - block.timestamp <= maxTimeDelta),
            ERR_INVALID_CREATE_TIME
        );
    }

    function _validateSpendTime(uint256 spendTime) private view {
        // Must be less than 32 bits and NOT in the past
        uint32 spendTimeSafe32 = UtilsLib.safe32(spendTime);

        require(
            spendTimeSafe32 <= block.timestamp &&
                (maxTimeDelta == 0 ||
                    block.timestamp - spendTimeSafe32 <= maxTimeDelta),
            ERR_INVALID_SPEND_TIME
        );
    }

    function _validateExtraInputHash(
        uint256 extraInputsHash,
        bytes memory extraInp
    ) private pure {
        require(
            extraInputsHash == uint256(keccak256(extraInp)) % FIELD_SIZE,
            ERR_INVALID_EXTRA_INPUT_HASH
        );
    }

    function _validateCachedForestRoot(
        uint256 forestMerkleRoot,
        uint256 cachedForestRootIndex
    ) private view {
        require(
            isCachedRoot(bytes32(forestMerkleRoot), cachedForestRootIndex),
            ERR_INVALID_FOREST_ROOT
        );
    }

    function _validateStaticRoot(uint256 staticMerkleRoot) private view {
        require(
            bytes32(staticMerkleRoot) == ITreeRootGetter(STATIC_TREE).getRoot(),
            ERR_INVALID_STATIC_ROOT
        );
    }

    function _validateNonZero(
        uint256 value,
        string memory errMsg
    ) private pure {
        require(value != 0, errMsg);
    }

    function _validateVaultAddress(
        address vault,
        uint256 publicInputParameter
    ) private pure {
        require(
            vault == publicInputParameter.safeAddress(),
            ERR_INVALID_VAULT_ADDRESS
        );
    }

    function _lockZkp(address from, uint256 amount) internal {
        VAULT.lockAsset(
            LockData(
                ERC20_TOKEN_TYPE,
                ZKP_TOKEN,
                // tokenId undefined for ERC-20
                0,
                from,
                amount.safe96()
            )
        );
    }
}
