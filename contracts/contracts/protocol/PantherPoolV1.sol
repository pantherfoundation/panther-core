// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023s Panther Ventures Limited Gibraltar
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

contract PantherPoolV1 is
    PantherForest,
    TransactionNoteEmitter,
    IPantherPoolV1
{
    // initialGap - PantherForest slots - CachedRoots slots => 500 - 22 - 25
    // slither-disable-next-line shadowing-state unused-state
    uint256[453] private __gap;

    IVault public immutable VAULT;
    address public immutable PROTOCOL_TOKEN;
    IBusTree public immutable BUS_TREE;
    IPantherVerifier public immutable VERIFIER;
    address public immutable ZACCOUNT_REGISTRY;

    mapping(address => bool) public vaultAssetUnlockers;

    uint160 public zAccountRegistrationCircuitId;

    constructor(
        address _owner,
        address zkpToken,
        address taxiTree,
        address busTree,
        address ferryTree,
        address staticTree,
        address vault,
        address zAccountRegistry,
        address verifier
    ) PantherForest(_owner, taxiTree, busTree, ferryTree, staticTree) {
        require(
            vault != address(0) &&
                zkpToken != address(0) &&
                verifier != address(0) &&
                zAccountRegistry != address(0),
            ERR_INIT
        );

        PROTOCOL_TOKEN = zkpToken;
        VAULT = IVault(vault);
        BUS_TREE = IBusTree(busTree);
        VERIFIER = IPantherVerifier(verifier);
        ZACCOUNT_REGISTRY = zAccountRegistry;
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

    function unlockAssetFromVault(LockData calldata data) external {
        require(vaultAssetUnlockers[msg.sender], ERR_UNAUTHORIZED);

        // Trusted contract - no reentrancy guard needed
        VAULT.unlockAsset(data);
    }

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
    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        address zkpPayer,
        bytes memory privateMessages,
        uint256 cachedForestRootIndex
    ) external returns (uint256 utxoBusQueuePos) {
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
        require(
            uint8(privateMessages[0]) == MT_UTXO_ZACCOUNT &&
                privateMessages.length >= LMT_UTXO_ZACCOUNT,
            ERR_NOT_WELLFORMED_SECRETS
        );
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

    function tempAddZAccountsUtxos(
        uint256[] calldata createTimes,
        uint256[] calldata commitments,
        bytes[] calldata privateMessages
    ) external onlyOwner {
        require(
            createTimes.length == commitments.length &&
                createTimes.length == privateMessages.length,
            "invalid length"
        );
        for (uint256 i = 0; i < createTimes.length; i++) {
            // Trusted contract - no reentrancy guard needed
            (uint32 queueId, uint8 indexInQueue) = BUS_TREE.addUtxoToBusQueue(
                bytes32(commitments[i])
            );

            bytes memory transactionNoteContent = abi.encodePacked(
                // First public message
                MT_UTXO_CREATE_TIME,
                createTimes[i],
                // Seconds public message
                MT_UTXO_BUSTREE_IDS,
                commitments[i],
                queueId,
                indexInQueue,
                // Private message(s)
                privateMessages[i]
            );

            emit TransactionNote(
                TT_ZACCOUNT_ACTIVATION,
                transactionNoteContent
            );
        }
    }
}
