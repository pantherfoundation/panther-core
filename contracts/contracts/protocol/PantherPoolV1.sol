// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023s Panther Ventures Limited Gibraltar
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly
pragma solidity ^0.8.16;

import "./interfaces/IVault.sol";
import "./interfaces/IPantherVerifier.sol";
import "./interfaces/IBusTree.sol";
import "./../common/ImmutableOwnable.sol";
import { ERC20_TOKEN_TYPE } from "./../common/Constants.sol";
import { LockData } from "./../common/Types.sol";
import "./../common/UtilsLib.sol";
import "./errMsgs/PantherPoolV1ErrMsgs.sol";
import "./pantherForest/PantherForest.sol";
import "./pantherPool/TransactionNoteEmitter.sol";
import "./interfaces/IPantherPoolV1.sol";
import "../common/UtilsLib.sol";

contract PantherPoolV1 is
    PantherForest,
    TransactionNoteEmitter,
    IPantherPoolV1
{
    // initialGap - PantherForest slots - CachedRoots slots => 500 - 22 - 25
    // slither-disable-next-line shadowing-state unused-state
    uint256[453] private __gap;

    uint256 private constant MAX_PRP_AMOUNT = (2 ** 64) - 1;

    IVault public immutable VAULT;
    address public immutable PROTOCOL_TOKEN;
    IBusTree public immutable BUS_TREE;
    IPantherVerifier public immutable VERIFIER;
    address public immutable ZACCOUNT_REGISTRY;
    address public immutable PRP_VOUCHER_GRANTOR;

    mapping(address => bool) public vaultAssetUnlockers;

    uint160 public zAccountRegistrationCircuitId;
    uint160 public prpAccountingCircuitId;
    uint160 public prpAccountConversionCircuitId;

    // TODO: to be removed when the total number of circuits in known
    uint256[10] private __circuiteIdsGap;

    // @notice Seen (i.e. spent) commitment nullifiers
    // nullifier hash => spent
    mapping(bytes32 => bool) public isSpent;

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
        VAULT = IVault(vault);
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
    }

    function updateZAccountRegistrationCircuitId(
        uint160 _circuitId
    ) external onlyOwner {
        zAccountRegistrationCircuitId = _circuitId;
    }

    function updatePrpAccountingCircuitId(
        uint160 _circuitId
    ) external onlyOwner {
        prpAccountingCircuitId = _circuitId;
    }

    function updatePrpAccountConversionCircuitId(
        uint160 _circuitId
    ) external onlyOwner {
        prpAccountConversionCircuitId = _circuitId;
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
    /// @param inputs[8]  - zAccountMasterEOA
    /// @param inputs[9]  - zAccountNullifier
    /// @param inputs[10] - zAccountCommitment
    /// @param inputs[11] - kycSignedMessageHash
    /// @param inputs[12] - forestMerkleRoot
    /// @param inputs[13] - saltHash
    /// @param inputs[14] - magicalConstraint
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
    )
        external
        validatePrivateMessage(privateMessages)
        returns (uint256 utxoBusQueuePos)
    {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(msg.sender == ZACCOUNT_REGISTRY, ERR_UNAUTHORIZED);
        require(zAccountRegistrationCircuitId != 0, ERR_UNDEFINED_CIRCUIT);
        {
            uint256 zAccountNullifier = inputs[9];
            require(zAccountNullifier != 0, ERR_ZERO_ZACCOUNT_NULLIFIER);
        }
        uint256 zAccountCommitment;
        {
            zAccountCommitment = inputs[10];
            require(zAccountCommitment != 0, ERR_ZERO_ZACCOUNT_COMMIT);
        }
        {
            uint256 kycSignedMessageHash = inputs[11];
            require(kycSignedMessageHash != 0, ERR_ZERO_KYC_MSG_HASH);
        }
        {
            uint256 saltHash = inputs[13];
            require(saltHash != 0, ERR_ZERO_SALT_HASH);
        }
        {
            uint256 magicalConstraint = inputs[14];
            require(magicalConstraint != 0, ERR_ZERO_MAGIC_CONSTR);
        }

        // Must be less than 32 bits and NOT in the past
        uint32 createTime = uint32(inputs[5]);
        require(
            uint256(createTime) == inputs[5] && createTime >= block.timestamp,
            ERR_INVALID_CREATE_TIME
        );

        require(
            isCachedRoot(bytes32(inputs[12]), cachedForestRootIndex),
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
    )
        external
        validatePrivateMessage(privateMessages)
        returns (uint256 utxoBusQueuePos)
    // solhint-disable-next-line no-empty-blocks
    {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(msg.sender == PRP_VOUCHER_GRANTOR, ERR_UNAUTHORIZED);
        require(prpAccountingCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        require(inputs[0] != 0, ERR_ZERO_EXTRA_INPUT_HASH);

        // Must be less than 32 bits and NOT in the past
        uint32 createTime = UtilsLib.safe32(inputs[2]);
        require(createTime >= block.timestamp, ERR_INVALID_CREATE_TIME);

        {
            uint256 depositAmountPrp = inputs[3];
            uint256 withdrawAmountPrp = inputs[4];
            require(
                depositAmountPrp <= MAX_PRP_AMOUNT &&
                    withdrawAmountPrp <= MAX_PRP_AMOUNT,
                ERR_TOO_LARGE_PRP_AMOUNT
            );
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

        uint256 zAccountUtxoOutCommitment = inputs[10];
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

    // TODO: Choosing better name (isn't it a kind of generate deposit?)
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
    function accountPrpConvertion(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        bytes memory privateMessages,
        uint256 zkpAmountOutRounded,
        uint256 cachedForestRootIndex
    )
        external
        validatePrivateMessage(privateMessages)
        returns (uint256 zAccountUtxoBusQueuePos)
    {
        // Note: This contract expects the Verifier to check the `inputs[]` are
        // less than the field size

        require(prpAccountConversionCircuitId != 0, ERR_UNDEFINED_CIRCUIT);

        require(inputs[0] != 0, ERR_ZERO_EXTRA_INPUT_HASH);

        // Must be less than 32 bits and NOT in the past
        uint32 createTime = UtilsLib.safe32(inputs[2]);
        require(createTime >= block.timestamp, ERR_INVALID_CREATE_TIME);

        {
            uint256 depositAmountPrp = inputs[3];
            uint256 withdrawAmountPrp = inputs[4];
            require(
                depositAmountPrp <= MAX_PRP_AMOUNT &&
                    withdrawAmountPrp <= MAX_PRP_AMOUNT,
                ERR_TOO_LARGE_PRP_AMOUNT
            );
        }

        uint256 zAssetScale = inputs[8];
        require(zAssetScale != 0, ERR_ZERO_ZASSET_SCALE);

        // Generating the new zAsset utxo commitment
        // Define zAssetUtxoCommitment here to avoid `stack too deep` error
        bytes32 zAssetUtxoCommitment;

        uint256 zkpAmountScaled = zkpAmountOutRounded / zAssetScale;
        uint256 zAssetUtxoCommitmentPrivatePart = inputs[5];

        zAssetUtxoCommitment = _generateZAssetUtxoCommitment(
            zAssetUtxoCommitmentPrivatePart,
            zkpAmountScaled,
            createTime
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

        {
            uint256 zNetworkChainId = inputs[11];
            require(zNetworkChainId == block.chainid, ERR_INVALID_CHAIN_ID);
        }

        require(
            isCachedRoot(bytes32(inputs[12]), cachedForestRootIndex),
            ERR_INVALID_FOREST_ROOT
        );

        {
            uint256 saltHash = inputs[13];
            require(saltHash != 0, ERR_ZERO_SALT_HASH);
        }

        {
            uint256 magicalConstraint = inputs[14];
            require(magicalConstraint != 0, ERR_ZERO_MAGIC_CONSTR);
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
            zkpAmountScaled,
            _privateMessages
        );

        emit TransactionNote(TT_PRP_CONVERSION, transactionNoteContent);
    }

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

    function _generateZAssetUtxoCommitment(
        uint256 zAssetUtxoPrivateDataHash,
        uint256 zAssetAmount,
        uint256 creationTime
    ) private pure returns (bytes32 zAssetUtxoCommitment) {
        zAssetUtxoCommitment = PoseidonHashers.poseidonT4(
            [
                bytes32(zAssetUtxoPrivateDataHash),
                bytes32(zAssetAmount),
                bytes32(creationTime)
            ]
        );
    }

    modifier validatePrivateMessage(bytes memory privateMessages) {
        require(
            uint8(privateMessages[0]) == MT_UTXO_ZACCOUNT &&
                privateMessages.length >= LMT_UTXO_ZACCOUNT,
            ERR_NOT_WELLFORMED_SECRETS
        );
        _;
    }
}
