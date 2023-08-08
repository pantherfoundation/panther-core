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

// solhint-disable var-name-mixedcase
// slither-disable shadowing-state
// slither-disable unused-state
contract PantherPoolV1 is
    PantherForest,
    TransactionNoteEmitter,
    IPantherPoolV1
{
    // slither-disable-next-line shadowing-state unused-state
    uint256[218] private __gap; // initialGap - pantherForest slots => 500 - 282

    IVault public immutable VAULT;
    IBusTree public immutable BUS_TREE;
    IPantherVerifier public immutable VERIFIER;
    uint16 public constant UNDEFINED_ROOT_INDEX = 0xFFFF;

    mapping(address => bool) public vaultAssetUnlockers;

    mapping(address => uint160) public circuitExecutor;

    uint160 public zAccountRegistrationCircuitId;

    constructor(
        address _owner,
        address vault,
        address taxiTree,
        address busTree,
        address ferryTree,
        address staticTree,
        address verifier
    ) PantherForest(_owner, taxiTree, busTree, ferryTree, staticTree) {
        require(
            vault != address(0) && verifier != address(0),
            "init: zero address"
        );

        VAULT = IVault(vault);
        BUS_TREE = IBusTree(busTree);
        VERIFIER = IPantherVerifier(verifier);
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

        VAULT.unlockAsset(data);
    }

    function createZAccountUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        bytes memory secretMessage,
        uint16 forestHistoryRootIndex
    )
        external
        returns (
            uint256 /*_res*/
        )
    {
        require(zAccountRegistrationCircuitId != 0, "undefined circuit");
        require(inputs[5] >= block.timestamp, "low zAccount creation time");
        require(
            _isForestRootExists(bytes32(inputs[12]), forestHistoryRootIndex),
            "forest root not found"
        );

        require(
            VERIFIER.verify(zAccountRegistrationCircuitId, inputs, proof),
            "BT:FAILED_PROOF"
        );

        bytes32 commitment = bytes32(inputs[9]);

        (uint32 queueId, uint8 indexInQueue) = BUS_TREE.addUtxoToBusQueue(
            commitment
        );

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

        return 0;
    }

    function _isForestRootExists(bytes32 _root, uint16 _rootIndex)
        private
        view
        returns (bool rootExists)
    {
        if (_rootIndex != UNDEFINED_ROOT_INDEX) {
            // Only checking the root index which has been defined by user
            rootExists = rootHistory[_rootIndex] == _root;
        } else {
            // User does not provided the index.
            // Iterating in history, starting from the latest index:
            uint8 depth = _historyDepth;

            while (!rootExists) {
                if (rootHistory[depth] == _root) rootExists = true;

                if (depth == 0) break;
                else {
                    unchecked {
                        depth--;
                    }
                }
            }
        }
    }
}
