// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "./pantherForest/interfaces/ITreeRootGetter.sol";
import "./pantherForest/interfaces/ITreeRootUpdater.sol";

import "./errMsgs/ProvidersKeysErrMsgs.sol";
import "./crypto/BabyJubJub.sol";
import { PoseidonT3, PoseidonT4 } from "./crypto/Poseidon.sol";

import "./providersKeys/ProvidersKeysSignatureVerifier.sol";
import "./pantherForest/merkleTrees/BinaryUpdatableTree.sol";
import { ZERO_VALUE } from "./pantherForest/zeroTrees/Constants.sol";

import "../common/ImmutableOwnable.sol";
import { G1Point } from "../common/Types.sol";

/**
 * @title ProvidersKeys
 * @author Pantherprotocol Contributors
 * @notice The contract registers public keys for providers, such as KYC/KYT attesters,
 * zone operators, and data escrow (or "data safe") operators. Contract owner (Multisig wallet)
 * is able to allocate empty leafs to each provider, so that the provider has a keyring to put
 * the keys maximum up to the given allocation.
 */
contract ProvidersKeys is
    ProvidersKeysSignatureVerifier,
    BinaryUpdatableTree,
    ImmutableOwnable,
    ITreeRootGetter
{
    // solhint-disable var-name-mixedcase

    uint32 private constant MAX_KEYS = 65536;
    uint256 private constant STATIC_TREE_LEAF_INDEX_FOR_PROVIDERS_KEYS_ROOT = 2;

    ITreeRootUpdater public immutable PANTHER_STATIC_TREE;

    // solhint-enable var-name-mixedcase

    /// @notice keyring status
    enum STATUS {
        UNDEFINED,
        ACTIVE,
        SUSPENDED
    }

    /// @notice keyring parameters
    struct Keyring {
        address operator;
        uint8 id;
        STATUS status;
        uint16 usedKeys;
        uint16 allocKeys;
        uint32 registrationBlockNum;
        uint16 _unused;
    }

    /// @notice keyring ID -> key index in the merkle tree
    mapping(uint32 => uint8) public keyOwners;

    /// @notice Mapping from operator to `Keyring`
    mapping(address => Keyring) public keyrings;

    /// @notice Total number of keyring which has been added
    uint16 private _keyringCounter;

    /// @notice Total number of keys which has been added in every keyring
    uint32 private _totalUsedKeys;

    /// @notice Total number of keys which has been reserved but not used yet
    uint32 private _totalAllocatedKeys;

    /// @notice flag to pause/unpause key registration, revocation and updating key expiry date
    bool public treeRootUpdatingAllowed;

    /// @notice current root of binry updatable merkle tree which has provider keys as its leaf
    bytes32 private currentRoot;

    event KeyringOperatorUpdated(
        address oldOperator,
        address newOperator,
        STATUS status
    );
    event KeyRegistered(uint8 id, uint256 keyIndex, G1Point key);
    event TreeRootUpdatingAllowedStatusChanged(bool status); //TODO

    constructor(
        address _owner,
        uint8 _keyringVersion,
        address pantherStaticTree
    ) ImmutableOwnable(_owner) ProvidersKeysSignatureVerifier(_keyringVersion) {
        require(pantherStaticTree != address(0), ERR_INIT_CONTRACT);

        PANTHER_STATIC_TREE = ITreeRootUpdater(pantherStaticTree);
    }

    modifier isTreeRootUpdatingAllowed() {
        require(treeRootUpdatingAllowed, ERR_TREE_ROOT_UPDATING_NOT_ALLOWED);
        _;
    }

    function getRoot() external view returns (bytes32) {
        return currentRoot;
    }

    function getKeyCommitment(G1Point memory key, uint32 expiryDate)
        public
        pure
        returns (bytes32 commitment)
    {
        commitment = PoseidonT4.poseidon(
            [bytes32(key.x), bytes32(key.y), bytes32(uint256(expiryDate))]
        );
    }

    function registerKey(
        G1Point memory key,
        uint32 expiryDate,
        bytes32[] memory proofSiblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external isTreeRootUpdatingAllowed {
        bytes32 keyPacked = BabyJubJub.pointPack(key);
        address operator = recoverOperator(keyPacked, expiryDate, v, r, s);

        Keyring memory _keyring = _getActivateKeyringOrRevert(operator);

        require(
            _keyring.allocKeys >= _keyring.usedKeys,
            ERR_INSUFFICIENT_KEY_ALLOCATION
        );
        require(expiryDate > block.timestamp, ERR_INVALID_KEY_EXPIRY_DATE);

        bytes32 commitment = getKeyCommitment(key, expiryDate);

        uint32 keyIndex = _totalUsedKeys;
        keyOwners[keyIndex] = _keyring.id;

        _updateProvidersKeysAndStaticTreeRoots(
            ZERO_VALUE,
            commitment,
            keyIndex,
            proofSiblings
        );

        keyIndex++;
        _totalUsedKeys = keyIndex;

        _keyring.usedKeys++;
        keyrings[msg.sender] = _keyring;

        emit KeyRegistered(_keyring.id, keyIndex, key);
    }

    function extendKeyExpiryDate(
        G1Point memory key,
        uint32 expiryDate,
        uint32 newExpiryDate,
        uint32 keyIndex,
        bytes32[] memory proofSiblings
    ) external isTreeRootUpdatingAllowed {
        Keyring memory _keyring = _getActivateKeyringOrRevert(msg.sender);

        require(keyIndex == keyOwners[_keyring.id], ERR_UNAUTHORIZED_KEY_OWNER);
        require(expiryDate > 0, ERR_REVOKED_KEY);

        bytes32 commitment = getKeyCommitment(key, expiryDate);
        bytes32 newCommitment = getKeyCommitment(key, newExpiryDate);

        _updateProvidersKeysAndStaticTreeRoots(
            commitment,
            newCommitment,
            keyIndex,
            proofSiblings
        );
    }

    function updateKeyringOperator(address newOperator) external {
        require(newOperator != address(0), ERR_ZERO_KEYRING_OPERATOR);

        Keyring memory _keyring = _getActivateKeyringOrRevert(msg.sender);
        address oldOperator = _keyring.operator;
        require(newOperator != oldOperator, ERR_REPETITIVE_KEYRING_OPERATOR);

        keyrings[newOperator] = _keyring;
        keyrings[msg.sender] = _resetKeyring(_keyring);

        emit KeyringOperatorUpdated(oldOperator, newOperator, STATUS.ACTIVE);
    }

    /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    function addKeyring(address operator, uint16 allocKeys) external onlyOwner {
        Keyring memory _keyring = keyrings[operator];
        require(_keyring.id == 0, ERR_KEYRING_ALREADY_EXISTS);
        uint32 totalAllocatedKeys = _totalAllocatedKeys;

        totalAllocatedKeys += allocKeys;
        require(MAX_KEYS >= totalAllocatedKeys, ERR_TOO_HIGH_KEY_ALLOCATION);

        uint16 keyringId = _getNextKeyringId();

        _keyring = Keyring({
            operator: operator,
            id: uint8(keyringId),
            status: STATUS.ACTIVE,
            usedKeys: 0,
            allocKeys: uint16(allocKeys),
            registrationBlockNum: uint32(block.number),
            _unused: 0
        });

        keyrings[operator] = _keyring;
        _keyringCounter = keyringId;
        _totalAllocatedKeys = totalAllocatedKeys;

        emit KeyringOperatorUpdated(address(0), operator, STATUS.ACTIVE);
    }

    function suspendKeyring(address account) external onlyOwner {
        Keyring memory _keyring = _getActivateKeyringOrRevert(account);

        _totalAllocatedKeys -= _getkeyringUnusedKeys(_keyring);

        keyrings[account] = _suspendKeyring(_keyring);

        emit KeyringOperatorUpdated(account, account, STATUS.SUSPENDED);
    }

    function reactivateKeyring(address operator) external onlyOwner {
        Keyring memory _keyring = keyrings[operator];
        require(
            _keyring.status == STATUS.SUSPENDED,
            ERR_KEYRING_ALREADY_ACTIVATED
        );

        uint32 totalAllocatedKeys = _totalAllocatedKeys;
        // Unused allocation before suspanding. To be allocated again.
        uint32 keyringUnUsedKeys = _getkeyringUnusedKeys(_keyring);
        totalAllocatedKeys += keyringUnUsedKeys;

        // When there is not enough empty keys to give back to keyring
        if (totalAllocatedKeys > MAX_KEYS) {
            keyringUnUsedKeys =
                MAX_KEYS -
                (totalAllocatedKeys - keyringUnUsedKeys);

            totalAllocatedKeys = MAX_KEYS;
        }

        keyrings[operator].status = STATUS.ACTIVE;
        _totalAllocatedKeys = totalAllocatedKeys;

        emit KeyringOperatorUpdated(operator, operator, STATUS.ACTIVE);
    }

    function extendKeyringKeyAllocation(address account, uint16 allocation)
        external
        onlyOwner
    {
        Keyring memory _keyring = _getActivateKeyringOrRevert(account);
        uint32 totalAllocatedKeys = _totalAllocatedKeys;
        totalAllocatedKeys += allocation;
        require(MAX_KEYS >= totalAllocatedKeys, ERR_TOO_HIGH_KEY_ALLOCATION);

        uint16 newKeyringAllocation = _keyring.allocKeys + allocation;

        keyrings[account].allocKeys = newKeyringAllocation;
        _totalAllocatedKeys = totalAllocatedKeys;
    }

    function revokeKey(
        G1Point memory key,
        address operator,
        uint32 expiryDate,
        uint32 keyIndex,
        bytes32[] calldata proofSiblings
    ) external {
        Keyring memory _keyring = _getActivateKeyringOrRevert(operator);

        require(
            OWNER == msg.sender || _keyring.operator == msg.sender,
            ERR_ONLY_OWNER_OR_KEYRING_OPERATOR
        );

        bytes32 commitment = getKeyCommitment(key, expiryDate);

        bytes32 newCommitment = getKeyCommitment(key, 0);

        _updateProvidersKeysAndStaticTreeRoots(
            commitment,
            newCommitment,
            keyIndex,
            proofSiblings
        );
    }

    function updateTreeRootUpdatingAllowedStatus(bool status)
        external
        onlyOwner
    {
        require(
            status != treeRootUpdatingAllowed,
            ERR_REPETITIVE_TREE_ROOT_UPDATING_STATUS
        );
        treeRootUpdatingAllowed = status;

        emit TreeRootUpdatingAllowedStatusChanged(status);
    }

    /* ========== INTERNAL & PRIVATE FUNCTIONS ========== */

    function _getNextKeyringId() private view returns (uint16) {
        return _keyringCounter + 1;
    }

    function _getActivateKeyringOrRevert(address operator)
        private
        view
        returns (Keyring memory)
    {
        Keyring memory _keyring = keyrings[operator];

        require(_keyring.id > 0, ERR_KEYRING_NOT_EXISTS);
        require(_keyring.status == STATUS.ACTIVE, ERR_KEYRING_NOT_ACTIVATED);

        return _keyring;
    }

    function _suspendKeyring(Keyring memory keyring)
        private
        pure
        returns (Keyring memory)
    {
        keyring.status = STATUS.SUSPENDED;
        return keyring;
    }

    function _resetKeyring(Keyring memory keyring)
        private
        pure
        returns (Keyring memory)
    {
        keyring = Keyring({
            operator: address(0),
            id: 0,
            status: STATUS.UNDEFINED,
            usedKeys: 0,
            allocKeys: 0,
            registrationBlockNum: 0,
            _unused: 0
        });

        return keyring;
    }

    function _getkeyringUnusedKeys(Keyring memory keyring)
        private
        pure
        returns (uint16)
    {
        return keyring.allocKeys - keyring.usedKeys;
    }

    function _updateProvidersKeysAndStaticTreeRoots(
        bytes32 leaf,
        bytes32 newLeaf,
        uint32 keyIndex,
        bytes32[] memory proofSiblings
    ) private {
        bytes32 _currentRoot = update(
            currentRoot,
            leaf,
            newLeaf,
            keyIndex,
            proofSiblings
        );

        currentRoot = _currentRoot;

        PANTHER_STATIC_TREE.updateRoot(
            _currentRoot,
            STATIC_TREE_LEAF_INDEX_FOR_PROVIDERS_KEYS_ROOT
        );
    }

    function hash(bytes32[2] memory input)
        internal
        pure
        override
        returns (bytes32)
    {
        require(
            BabyJubJub.isG1PointLowerThanFieldSize(
                [uint256(input[0]), uint256(input[1])]
            ),
            ERR_TOO_LARGE_LEAF_INPUTS
        );
        return PoseidonT3.poseidon(input);
    }

    // The root of zero merkle tree with depth 16 where each leaf is equal to
    // 0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d
    function zeroRoot() internal pure override returns (bytes32) {
        // Level 0: 0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d
        // Level 1: 0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4
        // Level 2: 0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8
        // Level 3: 0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c
        // Level 4: 0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800
        // Level 5: 0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f
        // Level 6: 0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69
        // Level 7: 0x225624653ac89fe211c0c3d303142a4caf24eb09050be08c33af2e7a1e372a0f
        // Level 8: 0x276c76358db8af465e2073e4b25d6b1d83f0b9b077f8bd694deefe917e2028d7
        // Level 9: 0x09df92f4ade78ea54b243914f93c2da33414c22328a73274b885f32aa9dea718
        // Level 10: 0x1c78b565f2bfc03e230e0cf12ecc9613ab8221f607d6f6bc2a583ccd690ecc58
        // Level 11: 0x2879d62c83d6a3af05c57a4aee11611a03edec5ff8860b07de77968f47ff1c5f
        // Level 12: 0x28ad970560de01e93b613aabc930fcaf087114743909783e3770a1ed07c2cde6
        // Level 13: 0x27ca60def9dd0603074444029cbcbeaa9dbe77668479ac1db738bb892d9f3b6d
        // Level 14: 0x28e4c1e90bbfa69de93abf6cbdc7cd1c0753a128e83b2b3afe34e0471a13ff55
        // Level 15: 0x1b89c44a9f153266ad5bf754d4b252c26acba7d21fc661b94dc0618c6a82f49c

        // Root: 0x0a5e5ec37bd8f9a21a1c2192e7c37d86bf975d947c2b38598b00babe567191c9
        return
            0x0a5e5ec37bd8f9a21a1c2192e7c37d86bf975d947c2b38598b00babe567191c9;
    }
}
