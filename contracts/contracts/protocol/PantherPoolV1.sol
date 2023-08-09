// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023s Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./interfaces/IVault.sol";
import "./interfaces/IPantherVerifier.sol";
import "./interfaces/IBusTree.sol";
import "./../common/ImmutableOwnable.sol";
import { LockData } from "./../common/Types.sol";
import "./pantherForest/PantherForest.sol";
import "./pantherPool/TransactionNoteEmitter.sol";
import "./interfaces/IPantherPoolV1.sol";

contract PantherPoolV1 is
    PantherForest,
    TransactionNoteEmitter,
    IPantherPoolV1
{
    // slither-disable-next-line shadowing-state unused-state
    uint256[218] private __gap; // initialGap - pantherForest slots => 500 - 282

    // solhint-disable var-name-mixedcase
    IVault public immutable VAULT;
    IBusTree public immutable BUS_TREE;
    IPantherVerifier public immutable VERIFIER;
    address public immutable ZACCOUNT_REGISTRY;
    // solhint-enable var-name-mixedcase

    mapping(address => bool) public vaultAssetUnlockers;

    uint160 public zAccountRegistrationCircuitId;

    constructor(
        address _owner,
        address vault,
        address taxiTree,
        address busTree,
        address ferryTree,
        address staticTree,
        address verifier,
        address zAccountRegistry
    ) PantherForest(_owner, taxiTree, busTree, ferryTree, staticTree) {
        require(
            vault != address(0) &&
                taxiTree != address(0) &&
                busTree != address(0) &&
                ferryTree != address(0) &&
                staticTree != address(0) &&
                verifier != address(0) &&
                zAccountRegistry != address(0),
            "init: zero address"
        );

        VAULT = IVault(vault);
        BUS_TREE = IBusTree(busTree);
        VERIFIER = IPantherVerifier(verifier);
        ZACCOUNT_REGISTRY = zAccountRegistry;
    }

    function updateVaultAssetUnlocker(address _unlocker, bool _status)
        external
        onlyOwner
    {
        vaultAssetUnlockers[_unlocker] = _status;
    }

    function updateZAccountRegistrationCircuitId(uint160 _circuitId)
        external
        onlyOwner
    {
        zAccountRegistrationCircuitId = _circuitId;
    }

    function unlockAssetFromVault(LockData calldata data) external {
        require(vaultAssetUnlockers[msg.sender], "mockPoolV1: unauthorized");

        // Trusted contract - no reentrancy guard needed
        VAULT.unlockAsset(data);
    }

    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        bytes memory secretMessage,
        uint256 cachedForestRootIndex
    ) external returns (uint256 utxoBusQueuePos) {
        require(msg.sender == ZACCOUNT_REGISTRY, "unauthorized");
        require(zAccountRegistrationCircuitId != 0, "undefined circuit");
        require(inputs[5] >= block.timestamp, "low zAccount creation time");
        require(
            isCachedRoot(bytes32(inputs[12]), cachedForestRootIndex),
            "forest root not found"
        );

        // Trusted contract - no reentrancy guard needed
        require(
            VERIFIER.verify(zAccountRegistrationCircuitId, inputs, proof),
            "BT:FAILED_PROOF"
        );

        bytes32 commitment = bytes32(inputs[9]);

        // Trusted contract - no reentrancy guard needed
        (uint32 queueId, uint8 indexInQueue) = BUS_TREE.addUtxoToBusQueue(
            commitment
        );
        utxoBusQueuePos = (uint256(queueId) << 8) | uint256(indexInQueue);

        bytes memory transactionNoteContent = abi.encodePacked(
            // First public message
            MT_UTXO_CREATION_TIME,
            inputs[5], // creationTime
            // Seconds public message
            MT_UTXO_BUSTREE_UTXO,
            inputs[11], // zAccountCommitment
            queueId,
            indexInQueue,
            // Private message
            secretMessage
        );

        emit TransactionNote(TT_ZACCOUNT_ACTIVATION, transactionNoteContent);
    }
}
