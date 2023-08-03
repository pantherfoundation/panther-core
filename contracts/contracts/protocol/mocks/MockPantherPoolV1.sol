// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023s Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../interfaces/IVault.sol";
import "../interfaces/IPantherVerifier.sol";
import "../interfaces/IBusTree.sol";
import "../../common/ImmutableOwnable.sol";
import { LockData } from "../../common/Types.sol";
import "../pantherForest/PantherForest.sol";
import "../pantherPool/TransactionNoteEmitter.sol";

interface IMockPantherPoolV1 {
    function unlockAssetFromVault(LockData calldata data) external;
}

// solhint-disable var-name-mixedcase
// slither-disable shadowing-state
// slither-disable unused-state
contract MockPantherPoolV1 is
    PantherForest,
    TransactionNoteEmitter,
    IMockPantherPoolV1
{
    // slither-disable-next-line shadowing-state unused-state
    uint256[500 - 290] private __gap;

    IVault public immutable VAULT;
    IBusTree public immutable BUS_TREE;
    IPantherVerifier public immutable VERIFIER;

    uint160 public zAccountRegistrationCircuitId;

    mapping(address => bool) public vaultAssetUnlockers;

    mapping(address => uint160) public circuitExecutor;

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
        bytes memory secretMessage
    )
        external
        returns (
            uint256 /*_res*/
        )
    {
        require(zAccountRegistrationCircuitId != 0, "undefined circuit");
        require(inputs[5] >= block.timestamp, "low zAccount creation time");

        require(
            VERIFIER.verify(zAccountRegistrationCircuitId, inputs, proof),
            "BT:FAILED_PROOF"
        );

        bytes32 commitment = bytes32(inputs[9]);

        (uint32 queueId, uint8 indexInQueue) = BUS_TREE.addUtxoToBusQueue(
            commitment
        );

        uint32 creationType = 1;

        bytes memory transactionNoteContent = abi.encodePacked(
            // First public message
            uint8(0x60),
            creationType,
            // Seconds public message
            uint8(0x62),
            inputs[11], // zAccountCommitment
            queueId,
            indexInQueue,
            // Private message
            secretMessage
        );

        emit TransactionNote(0x01, transactionNoteContent);

        return 0;
    }
}
