// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023s Panther Ventures Limited Gibraltar
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
pragma solidity ^0.8.16;

import "./interfaces/IPantherVerifier.sol";
import "./interfaces/IBusTree.sol";
import "./interfaces/IPantherPoolV1.sol";
import "./interfaces/IVaultV1.sol";

import "../../common/ImmutableOwnable.sol";
import { ERC20_TOKEN_TYPE, MAX_PRP_AMOUNT } from "../../common/Constants.sol";
import { LockData } from "../../common/Types.sol";
import "../../common/UtilsLib.sol";

import "./errMsgs/PantherPoolV1ErrMsgs.sol";

import "./pantherForest/PantherForest.sol";
import "./pantherPool/TransactionNoteEmitter.sol";

contract PantherPoolV1 is
    PantherForest,
    TransactionNoteEmitter,
    IPantherPoolV1
{
    // initialGap - PantherForest slots - CachedRoots slots => 500 - 22 - 25
    // slither-disable-next-line shadowing-state unused-state
    uint256[453] private __gap;

    IVaultV1 public immutable VAULT;
    address public immutable PROTOCOL_TOKEN;
    IBusTree public immutable BUS_TREE;
    IPantherVerifier public immutable VERIFIER;
    address public immutable ZACCOUNT_REGISTRY;
    address public immutable PRP_VOUCHER_GRANTOR;

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

    event ZAccountRegistrationCircuitIdUpdated(uint160 newId);
    event PrpAccountingCircuitIdUpdated(uint160 newId);
    event PrpAccountConversionCircuitIdUpdated(uint160 newId);
    event MainCircuitIdUpdated(uint160 newId);
    event KycRewardUpdated(uint256 newReward);
    event MaxTimeDeltaUpdated(uint256 newMaxTimeDelta);
    event VaultAssetUnlockerUpdated(address newAssetUnlocker, bool status);

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
    ) PantherForest(_owner, taxiTree, busTree, ferryTree, staticTree) {
        require(
            vault != address(0) &&
                zkpToken != address(0) &&
                verifier != address(0) &&
                zAccountRegistry != address(0) &&
                prpVoucherGrantor != address(0),
            ERR_INIT
        );

        PROTOCOL_TOKEN = zkpToken;
        VAULT = IVaultV1(vault);
        BUS_TREE = IBusTree(busTree);
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
    /// @param inputs[0]  - extraInputsHash
    /// @param inputs[1]  - zkpAmount
    /// @param inputs[2]  - zkpChange
    /// @param inputs[3]  - zAccountId
    /// @param inputs[4]  - zAccountPrpAmount
    /// @param inputs[5]  - zAccountCreateTime
    /// @param inputs[6]  - zAccountRootSpendPubKeyX
    /// @param inputs[7]  - zAccountRootSpendPubKeyY
    /// @param inputs[8]  - zAccountReadPubKeyX
    /// @param inputs[9]  - zAccountReadPubKeyY
    /// @param inputs[10] - zAccountNullifierPubKeyX
    /// @param inputs[11] - zAccountNullifierPubKeyY
    /// @param inputs[12] - zAccountMasterEOA
    /// @param inputs[13] - zAccountNullifier
    /// @param inputs[14] - zAccountCommitment
    /// @param inputs[15] - kycSignedMessageHash
    /// @param inputs[16] - forestMerkleRoot
    /// @param inputs[17] - saltHash
    /// @param inputs[18] - magicalConstraint
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param zkpPayer Wallet that withdraws onboarding zkp rewards
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// @param cachedForestRootIndex forest merkle root index. 0 means the most updated root.
    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        address zkpPayer,
        bytes memory privateMessages,
        uint256 cachedForestRootIndex
    ) external returns (uint256 utxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(msg.sender == ZACCOUNT_REGISTRY, ERR_UNAUTHORIZED);
        require(zAccountRegistrationCircuitId != 0, ERR_UNDEFINED_CIRCUIT);
        {
            uint256 zAccountNullifier = inputs[13];
            require(zAccountNullifier != 0, ERR_ZERO_ZACCOUNT_NULLIFIER);
        }
        uint256 zAccountCommitment;
        {
            zAccountCommitment = inputs[14];
            require(zAccountCommitment != 0, ERR_ZERO_ZACCOUNT_COMMIT);
        }
        {
            uint256 kycSignedMessageHash = inputs[15];
            require(kycSignedMessageHash != 0, ERR_ZERO_KYC_MSG_HASH);
        }
        {
            uint256 saltHash = inputs[17];
            require(saltHash != 0, ERR_ZERO_SALT_HASH);
        }
        {
            uint256 magicalConstraint = inputs[18];
            require(magicalConstraint != 0, ERR_ZERO_MAGIC_CONSTR);
        }

        // Must be less than 32 bits and NOT in the past
        uint32 createTime = uint32(inputs[5]);
        require(
            uint256(createTime) == inputs[5] && createTime >= block.timestamp,
            ERR_INVALID_CREATE_TIME
        );

        _sanitizePrivateMessage(privateMessages, TT_ZACCOUNT_ACTIVATION);

        require(
            isCachedRoot(bytes32(inputs[16]), cachedForestRootIndex),
            ERR_INVALID_FOREST_ROOT
        );

        // Trusted contract - no reentrancy guard needed
        require(
            VERIFIER.verify(zAccountRegistrationCircuitId, inputs, proof),
            ERR_FAILED_ZK_PROOF
        );

        if (inputs[1] != 0) {
            uint256 zkpAmount = inputs[1];
            _lockZkp(zkpPayer, zkpAmount);
        }

        // Trusted contract - no reentrancy guard needed
        (uint32 queueId, uint8 indexInQueue) = BUS_TREE.addUtxoToBusQueue(
            bytes32(zAccountCommitment)
        );
        utxoBusQueuePos = (uint256(queueId) << 8) | uint256(indexInQueue);

        bytes memory transactionNoteContent = abi.encodePacked(
            // First public message
            MT_UTXO_CREATE_TIME,
            createTime,
            // Seconds public message
            MT_UTXO_BUSTREE_IDS,
            zAccountCommitment, // zAccountCommitment
            queueId,
            indexInQueue,
            // Private message(s)
            privateMessages
        );

        emit TransactionNote(TT_ZACCOUNT_ACTIVATION, transactionNoteContent);
    }

    /// @notice Accounts prp to zAccount
    /// @dev It spends the old zAccount utxo and create a new one with increased
    /// prp balance. It can be executed only be prpVoucherGrantor.
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
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// This data is used to spend the newly created utxo.
    /// @param cachedForestRootIndex forest merkle root index. 0 means the most updated root.
    function accountPrp(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        bytes memory privateMessages,
        uint256 cachedForestRootIndex
    ) external returns (uint256 utxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        // Note: This contract expects the PrpVoucherGrantor to check the following inputs:
        // input[0], input[3], input[4],

        require(msg.sender == PRP_VOUCHER_GRANTOR, ERR_UNAUTHORIZED);
        require(prpAccountingCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        // Must be less than 32 bits and NOT in the past
        uint32 createTime = UtilsLib.safe32(inputs[2]);
        require(createTime >= block.timestamp, ERR_INVALID_CREATE_TIME);

        _sanitizePrivateMessage(privateMessages, TT_PRP_CLAIM);

        uint256 zAccountUtxoOutCommitment;
        {
            zAccountUtxoOutCommitment = inputs[10];
            require(zAccountUtxoOutCommitment != 0, ERR_ZERO_ZACCOUNT_COMMIT);
        }

        {
            // spending zAccount utxo
            bytes32 zAccountUtxoInNullifier = bytes32(inputs[9]);
            require(
                !isSpent[zAccountUtxoInNullifier],
                ERR_SPENT_ZACCOUNT_NULLIFIER
            );
            isSpent[zAccountUtxoInNullifier] = true;
        }

        {
            uint256 zNetworkChainId = inputs[11];
            require(zNetworkChainId == block.chainid, ERR_INVALID_CHAIN_ID);
        }

        {
            bytes32 forestMerkleRoot = bytes32(inputs[12]);
            require(
                isCachedRoot(forestMerkleRoot, cachedForestRootIndex),
                ERR_INVALID_FOREST_ROOT
            );
        }

        // Trusted contract - no reentrancy guard needed
        require(
            VERIFIER.verify(prpAccountingCircuitId, inputs, proof),
            ERR_FAILED_ZK_PROOF
        );

        // Trusted contract - no reentrancy guard needed
        (uint32 queueId, uint8 indexInQueue) = BUS_TREE.addUtxoToBusQueue(
            bytes32(zAccountUtxoOutCommitment)
        );

        utxoBusQueuePos = (uint256(queueId) << 8) | uint256(indexInQueue);

        bytes memory transactionNoteContent = abi.encodePacked(
            // First public message
            MT_UTXO_CREATE_TIME,
            createTime,
            MT_UTXO_BUSTREE_IDS,
            zAccountUtxoOutCommitment,
            queueId,
            indexInQueue,
            // Private message(s)
            privateMessages
        );

        emit TransactionNote(TT_PRP_CLAIM, transactionNoteContent);
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
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// This data is used to spend the newly created utxo.
    /// @param zkpAmountOutRounded The zkp amount to be locked in the vault, rounded by 1e12.
    /// @param cachedForestRootIndex forest merkle root index. 0 means the most updated root.
    function createZzkpUtxoAndSpendPrpUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        bytes memory privateMessages,
        uint256 zkpAmountOutRounded,
        uint256 cachedForestRootIndex
    ) external returns (uint256 zAccountUtxoBusQueuePos) {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(prpAccountConversionCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        {
            uint256 extraInputsHash = inputs[0];
            require(extraInputsHash != 0, ERR_ZERO_EXTRA_INPUT_HASH);
        }

        {
            uint256 saltHash = inputs[13];
            require(saltHash != 0, ERR_ZERO_SALT_HASH);
        }

        {
            uint256 magicalConstraint = inputs[14];
            require(magicalConstraint != 0, ERR_ZERO_MAGIC_CONSTR);
        }

        uint256 zAssetScale;
        {
            zAssetScale = inputs[8];
            require(zAssetScale != 0, ERR_ZERO_ZASSET_SCALE);
        }

        {
            uint256 zNetworkChainId = inputs[11];
            require(zNetworkChainId == block.chainid, ERR_INVALID_CHAIN_ID);
        }

        // Must be less than 32 bits and NOT in the past
        uint32 createTime = UtilsLib.safe32(inputs[2]);
        require(createTime >= block.timestamp, ERR_INVALID_CREATE_TIME);

        _sanitizePrivateMessage(privateMessages, TT_PRP_CONVERSION);

        require(
            isCachedRoot(bytes32(inputs[12]), cachedForestRootIndex),
            ERR_INVALID_FOREST_ROOT
        );

        {
            uint256 depositAmountPrp = inputs[3];
            uint256 withdrawAmountPrp = inputs[4];
            require(
                depositAmountPrp <= MAX_PRP_AMOUNT &&
                    withdrawAmountPrp <= MAX_PRP_AMOUNT,
                ERR_TOO_LARGE_PRP_AMOUNT
            );
        }

        // Generating the new zAsset utxo commitment
        // Define zAssetUtxoCommitment here to avoid `stack too deep` error
        bytes32 zAssetUtxoCommitment;

        uint256 zkpAmountScaled = zkpAmountOutRounded / zAssetScale;
        uint256 zAssetUtxoCommitmentPrivatePart = inputs[5];

        zAssetUtxoCommitment = _generateZAssetUtxoCommitment(
            zkpAmountScaled,
            zAssetUtxoCommitmentPrivatePart
        );

        {
            // spending zAccount utxo
            bytes32 zAccountUtxoInNullifier = bytes32(inputs[9]);
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

        bytes32 zAccountUtxoOutCommitment = bytes32(inputs[10]);
        bytes32[] memory utxos = new bytes32[](2);

        utxos[0] = zAccountUtxoOutCommitment;
        // new zAsset utxo commitment
        utxos[1] = zAssetUtxoCommitment;

        // The BusTree returns the queueId and index of the first utxo inside the utxos array, which is the zAccountUtxo
        (uint32 zAccountUtxoQueueId, uint8 zAccountUtxoIndexInQueue) = BUS_TREE
            .addUtxosToBusQueue(utxos);
        zAccountUtxoBusQueuePos =
            (uint256(zAccountUtxoQueueId) << 8) |
            uint256(zAccountUtxoIndexInQueue);

        _lockZkp(msg.sender, zkpAmountOutRounded);

        // solving stack too deep error when adding `privateMessages` to `transactionNoteContent`
        bytes memory _privateMessages = privateMessages;

        bytes memory transactionNoteContent = abi.encodePacked(
            MT_UTXO_CREATE_TIME,
            createTime, // createTime
            MT_UTXO_BUSTREE_IDS,
            zAccountUtxoOutCommitment,
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            MT_UTXO_ZASSET_PUB,
            UtilsLib.safe64(zkpAmountScaled),
            _privateMessages
        );

        emit TransactionNote(TT_PRP_CONVERSION, transactionNoteContent);
    }

    /// @param inputs The public input parameters to be passed to verifier.
    /// @param inputs[0]  - extraInputsHash;
    /// @param inputs[1]  - depositAmount;
    /// @param inputs[2]  - withdrawAmount;
    /// @param inputs[3]  - donatedAmountZkp;
    /// @param inputs[4]  - token;
    /// @param inputs[5]  - tokenId
    /// @param inputs[6]  - spendTime
    /// @param inputs[7]  - zAssetUtxoInNullifier1;
    /// @param inputs[8]  - zAssetUtxoInNullifier2;
    /// @param inputs[9] - zAccountUtxoInNullifier;
    /// @param inputs[10] - zZoneDataEscrowEphimeralPubKeyAx;
    /// @param inputs[11] - zZoneDataEscrowEncryptedMessageAx;
    /// @param inputs[12] - kytDepositSignedMessageSender;
    /// @param inputs[13] - kytDepositSignedMessageReceiver;
    /// @param inputs[14] - kytDepositSignedMessageHash;
    /// @param inputs[15] - kytWithdrawSignedMessageSender;
    /// @param inputs[16] - kytWithdrawSignedMessageReceiver;
    /// @param inputs[17] - kytWithdrawSignedMessageHash;
    /// @param inputs[18] - dataEscrowEphimeralPubKeyAx;
    /// @param inputs[19] - dataEscrowEncryptedMessageAx1;
    /// @param inputs[20] - dataEscrowEncryptedMessageAx2;
    /// @param inputs[21] - dataEscrowEncryptedMessageAx3;
    /// @param inputs[22] - dataEscrowEncryptedMessageAx4;
    /// @param inputs[23] - dataEscrowEncryptedMessageAx5;
    /// @param inputs[24] - dataEscrowEncryptedMessageAx6;
    /// @param inputs[25] - dataEscrowEncryptedMessageAx7;
    /// @param inputs[26] - dataEscrowEncryptedMessageAx8;
    /// @param inputs[27] - dataEscrowEncryptedMessageAx9;
    /// @param inputs[28] - dataEscrowEncryptedMessageAx10;
    /// @param inputs[29] - daoDataEscrowEphimeralPubKeyAx;
    /// @param inputs[30] - daoDataEscrowEncryptedMessageAx1;
    /// @param inputs[31] - daoDataEscrowEncryptedMessageAx2;
    /// @param inputs[32] - daoDataEscrowEncryptedMessageAx3;
    /// @param inputs[33] - utxoOutCreateTime;
    /// @param inputs[34] - zAssetUtxoOutCommitment1;
    /// @param inputs[35] - zAssetUtxoOutCommitment2;
    /// @param inputs[36] - zAccountUtxoOutCommitment;
    /// @param inputs[37] - chargedAmountZkp;
    /// @param inputs[38] - zNetworkChainId;
    /// @param inputs[39] - forestMerkleRoot;
    /// @param inputs[40] - saltHash;
    /// @param inputs[41] - magicalConstraint;
    function main(
        uint256[] memory inputs,
        SnarkProof calldata proof,
        uint256 cachedForestRootIndex,
        bytes memory privateMessages,
        uint8 tokenType,
        uint256 /*zkpChargedAmount*/
    ) external payable returns (uint256 zAccountUtxoBusQueuePos) {
        require(mainCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        {
            uint256 saltHash = inputs[40];
            _validateSaltHash(saltHash);
        }

        {
            uint256 magicalConstraint = inputs[41];
            _validateMagicalConstraint(magicalConstraint);
        }

        {
            uint256 zNetworkChainId = inputs[38];
            _validateZNetworkChainId(zNetworkChainId);
        }

        {
            uint256 extraInputsHash = inputs[0];
            bytes memory extraInp = abi.encodePacked(
                cachedForestRootIndex,
                privateMessages,
                tokenType
            );

            _validateExtraInputHash(extraInputsHash, extraInp);
        }

        {
            uint256 zZoneDataEscrowEphimeralPubKeyAx = inputs[10];
            require(
                zZoneDataEscrowEphimeralPubKeyAx != 0,
                ERR_ZERO_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
            );
        }

        {
            uint256 zZoneDataEscrowEncryptedMessageAx = inputs[11];
            require(
                zZoneDataEscrowEncryptedMessageAx != 0,
                ERR_ZERO_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
            );
        }

        {
            uint256 kytDepositSignedMessageHash = inputs[14];
            require(
                kytDepositSignedMessageHash != 0,
                ERR_ZERO_KYT_DEPOSIT_SIGNED_MESSAGE_HASH
            );
        }

        {
            uint256 kytWithdrawSignedMessageHash = inputs[17];
            require(
                kytWithdrawSignedMessageHash != 0,
                ERR_ZERO_KYT_WITHDRAW_SIGNED_MESSAGE_HASH
            );
        }

        {
            uint256 dataEscrowEphimeralPubKeyAx = inputs[18];
            require(
                dataEscrowEphimeralPubKeyAx != 0,
                ERR_ZERO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
            );
        }

        {
            require(
                inputs[19] != 0 &&
                    inputs[20] != 0 &&
                    inputs[21] != 0 &&
                    inputs[22] != 0 &&
                    inputs[23] != 0 &&
                    inputs[24] != 0 &&
                    inputs[25] != 0 &&
                    inputs[26] != 0 &&
                    inputs[27] != 0 &&
                    inputs[28] != 0,
                ERR_ZERO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
            );
        }

        {
            uint256 daoDataEscrowEphimeralPubKeyAx = inputs[29];
            require(
                daoDataEscrowEphimeralPubKeyAx != 0,
                ERR_ZERO_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX
            );
        }

        {
            uint256 daoDataEscrowEncryptedMessageAx1 = inputs[30];
            uint256 daoDataEscrowEncryptedMessageAx2 = inputs[31];
            uint256 daoDataEscrowEncryptedMessageAx3 = inputs[32];

            require(
                daoDataEscrowEncryptedMessageAx1 != 0,
                ERR_ZERO_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
            );
            require(
                daoDataEscrowEncryptedMessageAx2 != 0,
                ERR_ZERO_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
            );
            require(
                daoDataEscrowEncryptedMessageAx3 != 0,
                ERR_ZERO_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX
            );
        }

        _sanitizePrivateMessage(privateMessages, TT_MAIN_TRANSACTION);

        uint32 utxoOutCreateTime = _validateCreationTimeAndReturnSafe32(
            inputs[33]
        );

        uint32 spendTime = _validateSpendTimeAndReturnSafe32(inputs[6]);

        {
            bytes32 zAssetUtxoInNullifier1 = bytes32(inputs[7]);
            bytes32 zAssetUtxoInNullifier2 = bytes32(inputs[8]);

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
            bytes32 zAccountUtxoInNullifier = bytes32(inputs[9]);

            require(zAccountUtxoInNullifier > 0, ERR_ZERO_ZACCOUNT_NULLIFIER);

            require(
                !isSpent[zAccountUtxoInNullifier],
                ERR_SPENT_ZACCOUNT_NULLIFIER
            );
            isSpent[zAccountUtxoInNullifier] = true;
        }

        {
            uint256 depositAmount = inputs[1];
            uint256 withdrawAmount = inputs[2];
            uint256 token = inputs[4];

            if (depositAmount == 0 && withdrawAmount == 0)
                // internal tx
                require(token == 0, ERR_NON_ZERO_TOKEN);
            else {
                // depost or withdraw tx
                // NOTE: This contract expects the Vault will check the token (inputs[4]) to
                // be non-zero only if the tokenType is not native.
                _processDepositAndWithdraw(inputs, tokenType);
            }
        }

        uint96 miningRewards;
        {
            uint256 chargedAmountZkp = inputs[37];
            uint96 _accountedRewards;

            (miningRewards, _accountedRewards) = _distributeChargedZkps(
                chargedAmountZkp
            );

            accountedRewards += _accountedRewards;
        }

        {
            uint256 forestMerkleRoot = inputs[39];

            _validateCachedForestRootIndex(
                forestMerkleRoot,
                cachedForestRootIndex
            );
        }

        // Trusted contract - no reentrancy guard needed
        require(
            VERIFIER.verify(mainCircuitId, inputs, proof),
            ERR_FAILED_ZK_PROOF
        );

        bytes32 zAccountUtxoOutCommitment = bytes32(inputs[36]);

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;

        {
            bytes32 zAssetUtxoOutCommitment1 = bytes32(inputs[34]);
            bytes32 zAssetUtxoOutCommitment2 = bytes32(inputs[35]);
            bytes32[] memory utxos = new bytes32[](3);

            utxos[0] = zAccountUtxoOutCommitment;
            utxos[1] = zAssetUtxoOutCommitment1;
            utxos[2] = zAssetUtxoOutCommitment2;

            (
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                zAccountUtxoBusQueuePos
            ) = _addUtxosToBusQueue(utxos, miningRewards);
        }

        {
            // TODO find a clean/gas effecient solution
            // solving stack too deep error when adding `privateMessages` to `transactionNoteContent`
            bytes memory _privateMessages = privateMessages;

            bytes memory transactionNoteContent = abi.encodePacked(
                MT_UTXO_CREATE_TIME,
                utxoOutCreateTime,
                MT_UTXO_SPEND_TIME,
                spendTime,
                MT_UTXO_BUSTREE_IDS,
                zAccountUtxoOutCommitment,
                zAccountUtxoQueueId,
                zAccountUtxoIndexInQueue,
                _privateMessages
            );

            emit TransactionNote(TT_MAIN_TRANSACTION, transactionNoteContent);
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

    function _validateCreationTimeAndReturnSafe32(
        uint256 creationTime
    ) private view returns (uint32 creationTimeSafe32) {
        // Must be less than 32 bits and NOT in the past

        creationTimeSafe32 = UtilsLib.safe32(creationTime);

        require(
            creationTimeSafe32 >= block.timestamp &&
                (maxTimeDelta == 0 ||
                    creationTimeSafe32 - block.timestamp <= maxTimeDelta),
            ERR_INVALID_CREATE_TIME
        );
    }

    function _validateSpendTimeAndReturnSafe32(
        uint256 spendTime
    ) private view returns (uint32 spendTimeSafe32) {
        // Must be less than 32 bits and NOT in the past
        spendTimeSafe32 = UtilsLib.safe32(spendTime);

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

    function _addUtxosToBusQueue(
        bytes32[] memory utxos,
        uint96 rewards
    )
        private
        returns (
            uint32 zAccountUtxoQueueId,
            uint8 zAccountUtxoIndexInQueue,
            uint256 zAccountUtxoBusQueuePos
        )
    {
        try BUS_TREE.addUtxosToBusQueue(utxos, rewards) returns (
            uint32 firstUtxoQueueId,
            uint8 firstUtxoIndexInQueue
        ) {
            zAccountUtxoQueueId = firstUtxoQueueId;
            zAccountUtxoIndexInQueue = firstUtxoIndexInQueue;
        } catch Error(string memory reason) {
            revert(reason);
        }

        zAccountUtxoBusQueuePos =
            (uint256(zAccountUtxoQueueId) << 8) |
            uint256(zAccountUtxoIndexInQueue);
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

    function _generateZAssetUtxoCommitment(
        uint256 zAssetAmount,
        uint256 zAssetUtxoPrivateDataHash
    ) private pure returns (bytes32 zAssetUtxoCommitment) {
        zAssetUtxoCommitment = PoseidonHashers.poseidonT3(
            [bytes32(zAssetAmount), bytes32(zAssetUtxoPrivateDataHash)]
        );
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
        uint256[] memory inputs,
        uint8 tokenType
    ) private {
        uint96 depositAmount = UtilsLib.safe96(inputs[1]);
        uint96 withdrawAmount = UtilsLib.safe96(inputs[2]);

        address token = address(uint160(inputs[4]));
        uint256 tokenId = inputs[5];
        bytes32 saltHash = bytes32(inputs[40]);

        address kytDepositSignedMessageSender = address(uint160(inputs[12]));
        address kytDepositSignedMessageReceiver = address(uint160(inputs[13]));

        address kytWithdrawSignedMessageSender = address(uint160(inputs[15]));
        address kytWithdrawSignedMessageReceiver = address(uint160(inputs[16]));

        if (depositAmount > 0) {
            require(
                kytDepositSignedMessageReceiver == address(VAULT),
                ERR_INVALID_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER
            );

            require(
                kytWithdrawSignedMessageSender != address(0),
                ERR_INVALID_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER
            );

            require(
                kytWithdrawSignedMessageReceiver != address(0),
                ERR_INVALID_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER
            );

            _lockAssetWithSalt(
                SaltedLockData(
                    tokenType,
                    token,
                    tokenId,
                    saltHash,
                    kytDepositSignedMessageSender,
                    depositAmount
                )
            );
        }

        if (withdrawAmount > 0) {
            require(
                kytWithdrawSignedMessageSender == address(VAULT),
                ERR_INVALID_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER
            );
            require(
                kytDepositSignedMessageSender != address(0),
                ERR_INVALID_KYT_DEPOSIT_SIGNED_MESSAGE_SENDER
            );
            require(
                kytDepositSignedMessageReceiver != address(0),
                ERR_INVALID_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER
            );

            _unlockAsset(
                LockData(
                    tokenType,
                    token,
                    tokenId,
                    kytWithdrawSignedMessageReceiver,
                    withdrawAmount
                )
            );
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
