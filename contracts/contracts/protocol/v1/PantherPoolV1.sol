// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
pragma solidity ^0.8.19;

import "./interfaces/IPantherVerifier.sol";
import "./interfaces/IPantherTaxiTree.sol";
import "./interfaces/IBusTree.sol";
import "./interfaces/IPantherPoolV1.sol";
import "./interfaces/IVaultV1.sol";

import "../../common/NonReentrant.sol";
import "../../common/ImmutableOwnable.sol";
import { ERC20_TOKEN_TYPE, MAX_PRP_AMOUNT } from "../../common/Constants.sol";
import { LockData } from "../../common/Types.sol";
import "../../common/UtilsLib.sol";

import "./errMsgs/PantherPoolV1ErrMsgs.sol";

import "./pantherForest/PantherForest.sol";
import "./pantherPool/TransactionNoteEmitter.sol";
import "./pantherPool/UtxoCollector.sol";

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
    UtxoCollector,
    NonReentrant,
    IPantherPoolV1
{
    using TransactionOptions for uint32;
    // initialGap - PantherForest slots - CachedRoots slots => 500 - 22 - 25
    // slither-disable-next-line shadowing-state unused-state
    uint256[452] private __gap;

    IVaultV1 public immutable VAULT;
    address public immutable PROTOCOL_TOKEN;
    IPantherVerifier public immutable VERIFIER;
    address public immutable ZACCOUNT_REGISTRY;
    address public immutable PRP_VOUCHER_GRANTOR;
    address public immutable STATIC_TREE;

    mapping(address => bool) public vaultAssetUnlockers;

    // TODO added in a mapping: bytes4(keccak256(`circuit-name`)) => uint160
    uint160 public zAccountRegistrationCircuitId;
    uint160 public prpAccountingCircuitId;
    uint160 public prpAccountConversionCircuitId;
    uint160 public mainCircuitId;

    // TODO: to be removed when the total number of circuits in known
    uint256[9] private __circuiteIdsGap;

    // @notice Seen (i.e. spent) commitment nullifiers
    // nullifier hash => spent
    mapping(bytes32 => bool) public isSpent;

    uint96 public accountedRewards;
    uint96 public kycReward;
    // max difference between the given utxo create/spend time and now
    uint32 public maxTimeDelta;

    // kytMessageHash => blockNumber
    mapping(bytes32 => uint256) public seenKytMessageHashes;

    event ZAccountRegistrationCircuitIdUpdated(uint160 newId);
    event PrpAccountingCircuitIdUpdated(uint160 newId);
    event PrpAccountConversionCircuitIdUpdated(uint160 newId);
    event MainCircuitIdUpdated(uint160 newId);
    event KycRewardUpdated(uint256 newReward);
    event MaxTimeDeltaUpdated(uint256 newMaxTimeDelta);
    event VaultAssetUnlockerUpdated(address newAssetUnlocker, bool status);
    event SeenKytMessageHash(bytes32 indexed kytMessageHash);

    constructor(
        address _owner,
        address zkpToken,
        address taxiTree,
        address busTree,
        address ferryTree,
        address staticTree,
        address vault,
        address zAccountRegistry,
        address prpVoucherGrantor,
        address verifier
    )
        PantherForest(_owner, taxiTree, busTree, ferryTree)
        UtxoCollector(busTree, taxiTree)
    {
        require(
            staticTree != address(0) &&
                vault != address(0) &&
                zkpToken != address(0) &&
                verifier != address(0) &&
                zAccountRegistry != address(0) &&
                prpVoucherGrantor != address(0),
            ERR_INIT
        );

        STATIC_TREE = staticTree;
        PROTOCOL_TOKEN = zkpToken;
        VAULT = IVaultV1(vault);
        VERIFIER = IPantherVerifier(verifier);
        ZACCOUNT_REGISTRY = zAccountRegistry;
        PRP_VOUCHER_GRANTOR = prpVoucherGrantor;
    }

    function updateVaultAssetUnlocker(
        address _unlocker,
        bool _status
    ) external onlyOwner {
        vaultAssetUnlockers[_unlocker] = _status;

        emit VaultAssetUnlockerUpdated(_unlocker, _status);
    }

    function updateZAccountRegistrationCircuitId(
        uint160 _circuitId
    ) external onlyOwner {
        zAccountRegistrationCircuitId = _circuitId;

        emit ZAccountRegistrationCircuitIdUpdated(_circuitId);
    }

    function updatePrpAccountingCircuitId(
        uint160 _circuitId
    ) external onlyOwner {
        prpAccountingCircuitId = _circuitId;

        emit PrpAccountingCircuitIdUpdated(_circuitId);
    }

    function updatePrpAccountConversionCircuitId(
        uint160 _circuitId
    ) external onlyOwner {
        prpAccountConversionCircuitId = _circuitId;

        emit PrpAccountConversionCircuitIdUpdated(_circuitId);
    }

    function updateMainCircuitId(uint160 _circuitId) external onlyOwner {
        mainCircuitId = _circuitId;

        emit MainCircuitIdUpdated(_circuitId);
    }

    function updateKycReward(uint96 _kycReward) external onlyOwner {
        kycReward = _kycReward;

        emit KycRewardUpdated(_kycReward);
    }

    function updateMaxTimeDelta(uint32 _maxTimeDelta) external onlyOwner {
        maxTimeDelta = _maxTimeDelta;

        emit MaxTimeDeltaUpdated(_maxTimeDelta);
    }

    function unlockAssetFromVault(LockData calldata data) external {
        require(vaultAssetUnlockers[msg.sender], ERR_UNAUTHORIZED);

        // Trusted contract - no reentrancy guard needed
        VAULT.unlockAsset(data);
    }

    /// @notice Creates zAccount utxo
    /// @dev It can be executed only by zAccountsRegistry contract.
    /// @param inputs The public input parameters to be passed to verifier.
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param zkpPayer Wallet that withdraws onboarding zkp rewards
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        address zkpPayer,
        uint96 /*paymasterCompensation*/,
        bytes calldata privateMessages
    ) external nonReentrant returns (uint256 utxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(msg.sender == ZACCOUNT_REGISTRY, ERR_UNAUTHORIZED);
        require(zAccountRegistrationCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        _validateSaltHash(inputs[ZACCOUNT_ACTIVATION_SALT_HASH]);

        _validateMagicalConstraint(
            inputs[ZACCOUNT_ACTIVATION_MAGICAL_CONSTRAINT]
        );
        require(
            inputs[ZACCOUNT_ACTIVATION_NULLIFIER_ZONE] != 0,
            ERR_ZERO_ZACCOUNT_NULLIFIER
        );

        require(
            inputs[ZACCOUNT_ACTIVATION_UTXO_OUT_COMMITMENT] != 0,
            ERR_ZERO_ZACCOUNT_COMMIT
        );

        require(
            inputs[ZACCOUNT_ACTIVATION_KYC_SIGNED_MESSAGE_HASH] != 0,
            ERR_ZERO_KYC_MSG_HASH
        );

        _validateStaticRoot(inputs[ZACCOUNT_ACTIVATION_STATIC_MERKLE_ROOT]);

        _validateCreationTime(inputs[ZACCOUNT_ACTIVATION_UTXO_OUT_CREATE_TIME]);

        _sanitizePrivateMessage(privateMessages, TT_ZACCOUNT_ACTIVATION);

        _validateCachedForestRootIndex(
            inputs[ZACCOUNT_ACTIVATION_FOREST_MERKLE_ROOT],
            transactionOptions.cachedForestRootIndex()
        );

        // Trusted contract - no reentrancy guard needed
        require(
            VERIFIER.verify(zAccountRegistrationCircuitId, inputs, proof),
            ERR_FAILED_ZK_PROOF
        );

        if (inputs[ZACCOUNT_ACTIVATION_ADDED_AMOUNT_ZKP] != 0) {
            _lockZkp(zkpPayer, inputs[ZACCOUNT_ACTIVATION_ADDED_AMOUNT_ZKP]);
        }

        // TODO: getting from FeeMaster
        uint96 miningRewards;

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;
        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            utxoBusQueuePos
        ) = _insertZAccountActivationUtxos(
            inputs,
            transactionOptions,
            miningRewards
        );

        _emitZAccountActivationNote(
            inputs,
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            privateMessages
        );
    }

    /// @notice Accounts prp to zAccount
    /// @dev It spends the old zAccount utxo and create a new one with increased
    /// prp balance. It can be executed only be prpVoucherGrantor.
    /// @param inputs The public input parameters to be passed to verifier.
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
        uint96 /*paymasterCompensation*/,
        bytes calldata privateMessages
    ) external nonReentrant returns (uint256 utxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        // Note: This contract expects the PrpVoucherGrantor to check the following inputs:
        // input[0], input[3], input[4],

        require(msg.sender == PRP_VOUCHER_GRANTOR, ERR_UNAUTHORIZED);
        require(prpAccountingCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        _validateCreationTime(inputs[PRP_CLAIM_UTXO_OUT_CREATE_TIME]);

        _validateStaticRoot(inputs[PRP_CLAIM_STATIC_MERKLE_ROOT]);

        _sanitizePrivateMessage(privateMessages, TT_PRP_CLAIM);

        require(
            inputs[PRP_CLAIM_ZACCOUNT_UTXO_OUT_COMMITMENT] != 0,
            ERR_ZERO_ZACCOUNT_COMMIT
        );

        {
            // spending zAccount utxo
            bytes32 zAccountUtxoInNullifier = bytes32(
                inputs[PRP_CLAIM_ZACCOUNT_UTXO_IN_NULLIFIER]
            );
            require(
                !isSpent[zAccountUtxoInNullifier],
                ERR_SPENT_ZACCOUNT_NULLIFIER
            );
            isSpent[zAccountUtxoInNullifier] = true;
        }

        _validateZNetworkChainId(inputs[PRP_CLAIM_ZNETWORK_CHAIN_ID]);

        _validateCachedForestRootIndex(
            inputs[PRP_CLAIM_FOREST_MERKLE_ROOT],
            transactionOptions.cachedForestRootIndex()
        );

        // Trusted contract - no reentrancy guard needed
        require(
            VERIFIER.verify(prpAccountingCircuitId, inputs, proof),
            ERR_FAILED_ZK_PROOF
        );

        // TODO: getting from FeeMaster
        uint96 miningRewards;

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;
        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            utxoBusQueuePos
        ) = _insertPrpClaimUtxo(inputs, transactionOptions, miningRewards);

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
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// This data is used to spend the newly created utxo.
    /// @param zkpAmountOutRounded The zkp amount to be locked in the vault, rounded by 1e12.
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    function createZzkpUtxoAndSpendPrpUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 zkpAmountOutRounded,
        uint96 /*paymasterCompensation*/,
        bytes calldata privateMessages
    ) external nonReentrant returns (uint256 zAccountUtxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(prpAccountConversionCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        // Note: extraInputsHash is computed in PrpConverter
        require(
            inputs[PRP_CONVERSION_EXTRA_INPUT_HASH] != 0,
            ERR_ZERO_EXTRA_INPUT_HASH
        );

        _validateSaltHash(inputs[PRP_CONVERSION_SALT_HASH]);

        _validateMagicalConstraint(inputs[PRP_CONVERSION_MAGICAL_CONSTRAINT]);

        _validateStaticRoot(inputs[PRP_CONVERSION_STATIC_MERKLE_ROOT]);

        require(
            inputs[PRP_CONVERSION_ZASSET_SCALE] != 0,
            ERR_ZERO_ZASSET_SCALE
        );

        _validateZNetworkChainId(
            inputs[inputs[PRP_CONVERSION_ZNETWORK_CHAIN_ID]]
        );

        _validateCreationTime(inputs[PRP_CONVERSION_UTXO_OUT_CREATE_TIME]);

        _sanitizePrivateMessage(privateMessages, TT_PRP_CONVERSION);

        _validateCachedForestRootIndex(
            inputs[PRP_CONVERSION_FOREST_MERKLE_ROOT],
            transactionOptions.cachedForestRootIndex()
        );

        require(
            inputs[PRP_CONVERSION_DEPOSIT_PRP_AMOUNT] <= MAX_PRP_AMOUNT &&
                inputs[PRP_CONVERSION_WITHDRAW_PRP_AMOUNT] <= MAX_PRP_AMOUNT,
            ERR_TOO_LARGE_PRP_AMOUNT
        );

        {
            // spending zAccount utxo
            bytes32 zAccountUtxoInNullifier = bytes32(
                inputs[PRP_CONVERSION_ZACCOUNT_UTXO_IN_NULLIFIER]
            );
            require(
                !isSpent[zAccountUtxoInNullifier],
                ERR_SPENT_ZACCOUNT_NULLIFIER
            );
            isSpent[zAccountUtxoInNullifier] = true;
        }

        // Trusted contract - no reentrancy guard needed
        require(
            VERIFIER.verify(prpAccountConversionCircuitId, inputs, proof),
            ERR_FAILED_ZK_PROOF
        );

        uint256 zkpAmountScaled = zkpAmountOutRounded /
            inputs[PRP_CONVERSION_ZASSET_SCALE];

        // TODO: getting from FeeMaster
        uint96 miningRewards;

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;
        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zAccountUtxoBusQueuePos
        ) = _insertPrpConversionUtxos(
            inputs,
            zkpAmountOutRounded,
            transactionOptions,
            miningRewards
        );

        _lockZkp(msg.sender, zkpAmountOutRounded);

        _emitPrpConversionNote(
            inputs,
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            zkpAmountScaled,
            privateMessages
        );
    }

    /// @param inputs The public input parameters to be passed to verifier.
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
        require(mainCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        _validateSaltHash(inputs[MAIN_SALT_HASH]);

        _validateMagicalConstraint(inputs[MAIN_MAGICAL_CONSTRAINT]);

        _validateZNetworkChainId(inputs[MAIN_ZNETWORK_CHAIN_ID]);

        bytes memory extraInp = abi.encodePacked(
            transactionOptions,
            tokenType,
            paymasterCompensation,
            privateMessages
        );

        _validateExtraInputHash(inputs[MAIN_EXTRA_INPUT_HASH], extraInp);

        _validateStaticRoot(inputs[MAIN_STATIC_MERKLE_ROOT]);

        require(
            inputs[MAIN_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX] != 0,
            ERR_ZERO_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
        );

        require(
            inputs[MAIN_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_AX] != 0,
            ERR_ZERO_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
        );

        require(
            inputs[MAIN_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX] != 0,
            ERR_ZERO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
        );

        require(
            inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_1] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_2] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_3] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_4] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_5] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_6] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_7] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_8] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_9] != 0 &&
                inputs[MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_10] != 0,
            ERR_ZERO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
        );

        require(
            inputs[MAIN_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX] != 0,
            ERR_ZERO_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
        );

        require(
            inputs[MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_1] != 0,
            ERR_ZERO_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
        );
        require(
            inputs[MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_2] != 0,
            ERR_ZERO_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
        );
        require(
            inputs[MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_3] != 0,
            ERR_ZERO_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
        );

        _sanitizePrivateMessage(privateMessages, TT_MAIN_TRANSACTION);

        _validateCreationTime(inputs[MAIN_UTXO_OUT_CREATE_TIME]);

        _validateSpendTime(inputs[MAIN_SPEND_TIME]);

        {
            bytes32 zAssetUtxoInNullifier1 = bytes32(
                inputs[MAIN_ZASSET_UTXO_IN_NULLIFIER_1]
            );
            bytes32 zAssetUtxoInNullifier2 = bytes32(
                inputs[MAIN_ZASSET_UTXO_IN_NULLIFIER_2]
            );

            require(
                zAssetUtxoInNullifier1 > 0 && zAssetUtxoInNullifier2 > 0,
                ERR_ZERO_ZASSET_NULLIFIER
            );

            require(
                !isSpent[zAssetUtxoInNullifier1] &&
                    !isSpent[zAssetUtxoInNullifier2],
                ERR_SPENT_ZASSET_NULLIFIER
            );

            isSpent[zAssetUtxoInNullifier1] = true;
            isSpent[zAssetUtxoInNullifier2] = true;
        }

        {
            bytes32 zAccountUtxoInNullifier = bytes32(
                inputs[MAIN_ZACCOUNT_UTXO_IN_NULLIFIER]
            );

            require(zAccountUtxoInNullifier > 0, ERR_ZERO_ZACCOUNT_NULLIFIER);

            require(
                !isSpent[zAccountUtxoInNullifier],
                ERR_SPENT_ZACCOUNT_NULLIFIER
            );
            isSpent[zAccountUtxoInNullifier] = true;
        }

        uint96 protocolFee;

        {
            if (
                inputs[MAIN_DEPOSIT_AMOUNT] == 0 &&
                inputs[MAIN_WITHDRAW_AMOUNT] == 0
            )
                // internal tx
                require(inputs[MAIN_TOKEN] == 0, ERR_NON_ZERO_TOKEN);
            else {
                // depost or withdraw tx
                // NOTE: This contract expects the Vault will check the token (inputs[4]) to
                // be non-zero only if the tokenType is not native.
                _processDepositAndWithdraw(inputs, tokenType, protocolFee);
            }
        }

        // TODO: getting from FeeMaster
        uint96 miningRewards;
        {
            uint256 chargedAmountZkp = inputs[MAIN_CHARGED_AMOUNT_ZKP];
            uint96 _accountedRewards;

            (miningRewards, _accountedRewards) = _distributeChargedZkps(
                chargedAmountZkp
            );

            accountedRewards += _accountedRewards;
        }

        _validateCachedForestRootIndex(
            inputs[MAIN_FOREST_MERKLE_ROOT],
            transactionOptions.cachedForestRootIndex()
        );

        // Trusted contract - no reentrancy guard needed
        require(
            VERIFIER.verify(mainCircuitId, inputs, proof),
            ERR_FAILED_ZK_PROOF
        );

        {
            uint32 zAccountUtxoQueueId;
            uint8 zAccountUtxoIndexInQueue;
            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _insertMainUtxos(inputs, transactionOptions, miningRewards);

            _emitMainNote(
                inputs,
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                privateMessages
            );
        }
    }

    function _validateSaltHash(uint256 saltHash) private pure {
        require(saltHash != 0, ERR_ZERO_SALT_HASH);
    }

    function _validateMagicalConstraint(
        uint256 magicalConstraint
    ) private pure {
        require(magicalConstraint != 0, ERR_ZERO_MAGIC_CONSTR);
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

    function _validateCachedForestRootIndex(
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

    function _lockAssetWithSalt(SaltedLockData memory slData) private {
        // Trusted contract - no reentrancy guard needed
        // solhint-disable-next-line no-empty-blocks
        try VAULT.lockAssetWithSalt{ value: msg.value }(slData) {} catch Error(
            string memory reason
        ) {
            revert(reason);
        }
    }

    function _unlockAsset(LockData memory lData) private {
        // Trusted contract - no reentrancy guard needed
        // solhint-disable-next-line no-empty-blocks
        try VAULT.unlockAsset(lData) {} catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _distributeChargedZkps(
        uint256 chargedAmount
    ) internal view returns (uint96 _miningReward, uint96 _accountedRewards) {
        _accountedRewards = kycReward;
        require(chargedAmount > _accountedRewards, ERR_TOO_LOW_CHARGED_ZKP);
        //TODO Subtract other rewards (protocol, etc) from `chargedAmount`
        _miningReward = UtilsLib.safe96(chargedAmount - _accountedRewards);
    }

    function _processDepositAndWithdraw(
        uint256[] calldata inputs,
        uint8 tokenType,
        uint96 protocolFee
    ) private {
        uint96 depositAmount = UtilsLib.safe96(MAIN_DEPOSIT_AMOUNT);
        uint96 withdrawAmount = UtilsLib.safe96(MAIN_WITHDRAW_AMOUNT);

        address token = address(uint160(inputs[MAIN_TOKEN]));
        uint256 tokenId = inputs[MAIN_TOKEN_ID];

        if (depositAmount > 0) {
            bytes32 kytDepositSignedMessageHash = bytes32(
                inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_HASH]
            );

            require(
                address(
                    uint160(inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER])
                ) == address(VAULT),
                ERR_INVALID_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER
            );

            require(
                kytDepositSignedMessageHash != 0,
                ERR_ZERO_KYT_DEPOSIT_SIGNED_MESSAGE_HASH
            );
            require(
                seenKytMessageHashes[kytDepositSignedMessageHash] == 0,
                ERR_DUPLICATED_KYT_MESSAGE_HASH
            );

            seenKytMessageHashes[kytDepositSignedMessageHash] = block.number;

            _lockAssetWithSalt(
                SaltedLockData(
                    tokenType,
                    token,
                    tokenId,
                    bytes32(inputs[MAIN_SALT_HASH]),
                    address(
                        uint160(inputs[MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_SENDER])
                    ),
                    depositAmount
                )
            );

            emit SeenKytMessageHash(kytDepositSignedMessageHash);
        }

        if (withdrawAmount > 0) {
            withdrawAmount = protocolFee > 0
                ? withdrawAmount - protocolFee
                : withdrawAmount;

            bytes32 kytWithdrawSignedMessageHash = bytes32(
                inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH]
            );

            require(
                address(
                    uint160(inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER])
                ) == address(VAULT),
                ERR_INVALID_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER
            );

            require(
                kytWithdrawSignedMessageHash != 0,
                ERR_ZERO_KYT_WITHDRAW_SIGNED_MESSAGE_HASH
            );
            require(
                seenKytMessageHashes[kytWithdrawSignedMessageHash] == 0,
                ERR_DUPLICATED_KYT_MESSAGE_HASH
            );

            seenKytMessageHashes[kytWithdrawSignedMessageHash] = block.number;

            _unlockAsset(
                LockData(
                    tokenType,
                    token,
                    tokenId,
                    address(
                        uint160(
                            inputs[MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER]
                        )
                    ),
                    withdrawAmount
                )
            );

            emit SeenKytMessageHash(kytWithdrawSignedMessageHash);
        }
    }

    // TODO: to be deleted in prod
    function _lockZkp(address from, uint256 amount) internal {
        // Trusted contract - no reentrancy guard needed
        VAULT.lockAsset(
            LockData(
                ERC20_TOKEN_TYPE,
                PROTOCOL_TOKEN,
                // tokenId undefined for ERC-20
                0,
                from,
                UtilsLib.safe96(amount)
            )
        );
    }
}
