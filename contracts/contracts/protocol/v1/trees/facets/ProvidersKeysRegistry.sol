// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ProvidersKeysRegistryStorageGap.sol";

import "./staticTrees/ProvidersKeysRegistry/ProvidersKeysSignatureVerifier.sol";
import "../errMsgs/ProvidersKeysErrMsgs.sol";

import "./staticTrees/StaticRootUpdater.sol";

import "../../diamond/utils/Ownable.sol";
import "../utils/merkleTrees/BinaryUpdatableTree.sol";
import { PROVIDERS_KEYS_STATIC_LEAF_INDEX } from "../utils/Constants.sol";
import { SIXTEEN_LEVELS, SIXTEEN_LEVEL_EMPTY_TREE_ROOT, ZERO_VALUE } from "../utils/zeroTrees/Constants.sol";

import "../../../../common/UtilsLib.sol";
import "../../../../common/crypto/BabyJubJub.sol";
import "../../../../common/crypto/PoseidonHashers.sol";

/**
 * @title ProvidersKeys
 * @author Pantherprotocol Contributors
 * @notice It registers public keys of providers, such as KYC/KYT attesters,
 * zone operators, data escrow (or "data safe") operators.
 * Each public key is stored as a leaf of a binary merkle tree. Every time the
 * tree is updated, this contract calls `PantherStaticTree` smart contract to
 * notify on update of the tree root.
 * The contract owner allocates leafs ("keyring") to a provider and authorizes
 * an address that may register provider's keys.
 * This way a provider gets the "keyring" where the provider may put that many
 * keys as the owner allocated.
 * @dev Public keys are points in the BabyJubjub elliptic curve. The contract
 * does not check, however, if the key is a valid curve point.
 * Since the off-chain computation of the tree updates proved by the SNARK will
 * replace the on-chain computation in the next version, the "incremental tree"
 * algorithm is not applied ("incremental tree" is easier for operators since
 * `proofSiblings` unneeded as input params on tree leafs insertions/updates).
 */
abstract contract ProvidersKeysRegistry is
    ProvidersKeysSignatureVerifier,
    StaticRootUpdater,
    Ownable,
    BinaryUpdatableTree
{
    // solhint-disable var-name-mixedcase
    // TODO add `constant` label to these variables
    uint256 private KEYS_TREE_DEPTH = SIXTEEN_LEVELS;
    uint16 private constant MAX_KEYS = uint16(2 ** SIXTEEN_LEVELS - 1);

    uint32 private REVOKED_KEY_EXPIRY = 0;
    uint256 private MAX_TREE_LOCK_PERIOD = 30 days;

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
        STATUS status;
        uint16 numKeys;
        uint16 numAllocKeys;
        uint32 registrationBlock;
        uint24 _unused;
    }

    /// @notice Mapping from keyring ID to Keyring data
    mapping(uint16 => Keyring) public keyrings;

    /// @notice Mapping from key index to keyring ID
    mapping(uint16 => uint16) public keyringIds;

    /// @dev Number of keyrings added (created) so far
    uint16 private _numKeyrings;

    /// @dev Number of public keys registered so far
    uint16 private _totalNumRegisteredKeys;

    /// @dev Number of leafs reserved for public keys so far
    uint16 private _totalNumAllocatedKeys;

    /// @dev (UNIX) time till when operators can't register/revoke/extend keys
    /// @dev Owner may temporally disable the tree changes by operators to avoid
    /// the "race condition" (if multiple parties try to update simultaneously)
    uint32 private _treeLockedTillTime;

    /// @dev Root of the merkle tree with registered keys
    bytes32 private _currentRoot;

    event KeyRegistered(
        uint16 indexed keyringId,
        uint16 indexed keyIndex,
        bytes32 packedPubKey,
        uint32 expiry
    );
    event KeyExtended(
        uint16 indexed keyringId,
        uint16 indexed keyIndex,
        uint32 newExpiry
    );
    event KeyRevoked(uint16 indexed keyringId, uint16 indexed keyIndex);

    event KeyringUpdated(
        uint16 indexed keyringId,
        address operator,
        STATUS status,
        uint16 numAllocKeys
    );

    event TreeLockUpdated(uint32 tillTime);

    constructor(
        address self,
        uint8 keyringVersion
    ) StaticRootUpdater(self) ProvidersKeysSignatureVerifier(keyringVersion) {}

    modifier whenTreeUnlocked() {
        _requireTreeIsUnlocked();
        _;
    }

    modifier keyInKeyring(uint16 keyIndex, uint16 keyringId) {
        require(keyringIds[keyIndex] == keyringId, ERR_KEY_IS_NOT_IN_KEYRING);
        _;
    }

    modifier sanitizePubKey(G1Point memory pubKey) {
        // Ensure the pubKey is a Baby Jubjub curve point (subgroup isn't ensured -
        // consider calling `isAcceptablePubKey` off-chain before registration)
        BabyJubJub.requirePointInCurveExclIdentity(pubKey);
        _;
    }

    function getStatistics()
        external
        view
        returns (
            uint16 numKeyrings,
            uint16 totalNumRegisteredKeys,
            uint16 totalNumAllocatedKeys,
            uint32 treeLockedTillTime
        )
    {
        numKeyrings = _numKeyrings;
        totalNumRegisteredKeys = _totalNumRegisteredKeys;
        totalNumAllocatedKeys = _totalNumAllocatedKeys;
        treeLockedTillTime = _treeLockedTillTime;
    }

    function getProvidersKeysRoot() external view returns (bytes32) {
        return _currentRoot == bytes32(0) ? zeroRoot() : _currentRoot;
    }

    /// @notice Returns true if the pubKey is acceptable.
    /// Off-chain call (gas cost is high) advised to precede pubKey registration.
    /// @dev The pub key must be a point in the subgroup (excluding the identity)
    /// of Baby Jubjub curve points in the twisted Edwards form.
    function isAcceptablePubKey(
        G1Point memory pubKey
    ) external view returns (bool) {
        return
            !BabyJubJub.isIdentity(pubKey) && BabyJubJub.isInSubgroup(pubKey);
    }

    /// @notice It returns the pubKey in the packed form for the given pubKey.
    function packPubKey(G1Point memory pubKey) public pure returns (bytes32) {
        return BabyJubJub.pointPack(pubKey);
    }

    function getKeyCommitment(
        G1Point memory pubKey,
        uint32 expiry
    ) public pure returns (bytes32 commitment) {
        // Next call reverts if the input is not in the SNARK field
        commitment = PoseidonHashers.poseidonT4(
            [bytes32(pubKey.x), bytes32(pubKey.y), bytes32(uint256(expiry))]
        );
    }

    function registerKeyWithSignature(
        uint16 keyringId,
        G1Point memory pubKey,
        uint32 expiry,
        bytes32[] memory proofSiblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint16 keyIndex) {
        address operator = recoverOperator(
            keyringId,
            pubKey,
            expiry,
            proofSiblings,
            v,
            r,
            s
        );

        keyIndex = _registerKey(
            operator,
            keyringId,
            pubKey,
            expiry,
            proofSiblings
        );
    }

    function registerKey(
        uint16 keyringId,
        G1Point memory pubKey,
        uint32 expiry,
        bytes32[] memory proofSiblings
    ) external returns (uint16 keyIndex) {
        keyIndex = _registerKey(
            msg.sender,
            keyringId,
            pubKey,
            expiry,
            proofSiblings
        );
    }

    function extendKeyExpiryWithSignature(
        uint16 keyIndex,
        G1Point memory pubKey,
        uint32 expiry,
        uint32 newExpiry,
        bytes32[] memory proofSiblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        uint16 keyringId = keyringIds[keyIndex];

        address operator = recoverOperator(
            keyIndex,
            pubKey,
            expiry,
            newExpiry,
            proofSiblings,
            v,
            r,
            s
        );

        _getOperatorActiveKeyringOrRevert(keyringId, operator);

        _extendKeyExpiry(
            pubKey,
            expiry,
            newExpiry,
            keyIndex,
            keyringId,
            proofSiblings
        );
    }

    function extendKeyExpiry(
        G1Point memory pubKey,
        uint32 expiry,
        uint32 newExpiry,
        uint16 keyIndex,
        bytes32[] memory proofSiblings
    ) external {
        uint16 keyringId = keyringIds[keyIndex];
        _getOperatorActiveKeyringOrRevert(keyringId, msg.sender);

        _extendKeyExpiry(
            pubKey,
            expiry,
            newExpiry,
            keyIndex,
            keyringId,
            proofSiblings
        );
    }

    function updateKeyringOperatorWithSignature(
        uint16 keyringId,
        address newOperator,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        address currentoperator = recoverOperator(
            keyringId,
            newOperator,
            v,
            r,
            s
        );

        _updateKeyringOperator(keyringId, currentoperator, newOperator);
    }

    function updateKeyringOperator(
        uint16 keyringId,
        address newOperator
    ) external {
        _updateKeyringOperator(keyringId, msg.sender, newOperator);
    }

    function revokeKeyWithSignature(
        uint16 keyringId,
        uint16 keyIndex,
        G1Point memory pubKey,
        uint32 expiry,
        bytes32[] calldata proofSiblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        address operator = recoverOperator(
            keyringId,
            keyIndex,
            pubKey,
            expiry,
            proofSiblings,
            v,
            r,
            s
        );

        _revokeKey(
            operator,
            keyringId,
            keyIndex,
            pubKey,
            expiry,
            proofSiblings
        );
    }

    /// @notice Revoke registered key. Either the operator or the owner may call.
    /// @dev It sets the `expiry` to 0, which is an indicator of a revoked key.
    function revokeKey(
        uint16 keyringId,
        uint16 keyIndex,
        G1Point memory pubKey,
        uint32 expiry,
        bytes32[] calldata proofSiblings
    ) external {
        _revokeKey(
            msg.sender,
            keyringId,
            keyIndex,
            pubKey,
            expiry,
            proofSiblings
        );
    }

    /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    function addKeyring(
        address operator,
        uint16 numAllocKeys
    ) external onlyOwner {
        require(operator != address(0), ERR_ZERO_OPERATOR_ADDRESS);

        uint16 numAllocatedKeys = _totalNumAllocatedKeys;
        numAllocatedKeys += numAllocKeys;
        require(MAX_KEYS >= numAllocatedKeys, ERR_TOO_HIGH_ALLOCATION);

        uint16 keyringId = _getNextKeyringId();
        keyrings[keyringId] = Keyring({
            operator: operator,
            status: STATUS.ACTIVE,
            numKeys: 0,
            numAllocKeys: numAllocKeys,
            registrationBlock: UtilsLib.safe32BlockNow(),
            _unused: 0
        });

        _numKeyrings = keyringId;
        _totalNumAllocatedKeys = numAllocatedKeys;

        emit KeyringUpdated(keyringId, operator, STATUS.ACTIVE, numAllocKeys);
    }

    function suspendKeyring(uint16 keyringId) external onlyOwner {
        Keyring memory keyring = _getActiveKeyringOrRevert(keyringId);

        _totalNumAllocatedKeys -= _getUnusedKeyringAllocation(keyring);

        keyrings[keyringId] = _suspendKeyring(keyring);

        emit KeyringUpdated(
            keyringId,
            keyring.operator,
            keyring.status,
            keyring.numAllocKeys
        );
    }

    function reactivateKeyring(uint16 keyringId) external onlyOwner {
        Keyring memory keyring = keyrings[keyringId];
        require(
            keyring.status == STATUS.SUSPENDED,
            ERR_KEYRING_ALREADY_ACTIVATED
        );

        uint16 numAllocatedKeys = _totalNumAllocatedKeys;
        // Unused allocation before suspending. To be allocated again.
        uint16 keyringUnusedKeys = _getUnusedKeyringAllocation(keyring);
        numAllocatedKeys += keyringUnusedKeys;

        // When there is not enough empty keys to give back to keyring
        if (numAllocatedKeys > MAX_KEYS) {
            keyringUnusedKeys =
                MAX_KEYS -
                (numAllocatedKeys - keyringUnusedKeys);

            numAllocatedKeys = MAX_KEYS;
        }

        keyring.status = STATUS.ACTIVE;
        keyrings[keyringId] = keyring;
        _totalNumAllocatedKeys = numAllocatedKeys;

        emit KeyringUpdated(
            keyringId,
            keyring.operator,
            keyring.status,
            keyring.numAllocKeys
        );
    }

    function increaseKeyringKeyAllocation(
        uint16 keyringId,
        uint16 allocation
    ) external onlyOwner {
        Keyring memory keyring = _getActiveKeyringOrRevert(keyringId);
        uint16 numAllocatedKeys = _totalNumAllocatedKeys;
        numAllocatedKeys += allocation;
        require(MAX_KEYS >= numAllocatedKeys, ERR_TOO_HIGH_ALLOCATION);

        uint16 newKeyringAllocation = keyring.numAllocKeys + allocation;

        keyrings[keyringId].numAllocKeys = newKeyringAllocation;
        _totalNumAllocatedKeys = numAllocatedKeys;

        emit KeyringUpdated(
            keyringId,
            keyring.operator,
            keyring.status,
            keyring.numAllocKeys
        );
    }

    function updateTreeLock(uint32 lockPeriod) external onlyOwner {
        require(
            lockPeriod <= MAX_TREE_LOCK_PERIOD,
            ERR_TREE_LOCK_ALREADY_UPDATED
        );
        uint32 timestamp = UtilsLib.safe32(_timeNow() + lockPeriod);
        _treeLockedTillTime = timestamp;

        emit TreeLockUpdated(timestamp);
    }

    /* ========== INTERNAL & PRIVATE FUNCTIONS ========== */

    function zeroRoot() internal pure override returns (bytes32) {
        return SIXTEEN_LEVEL_EMPTY_TREE_ROOT;
    }

    function hash(
        bytes32[2] memory input
    ) internal pure override returns (bytes32) {
        // Next call reverts if the input is not in the SNARK field
        return PoseidonHashers.poseidonT3(input);
    }

    /// @notice Register a public key. Only the keyring operator may call.
    /// @dev Consider `isAcceptablePubKey` off-chain call before registration.
    function _registerKey(
        address operator,
        uint16 keyringId,
        G1Point memory pubKey,
        uint32 expiry,
        bytes32[] memory proofSiblings
    )
        private
        sanitizePubKey(pubKey)
        whenTreeUnlocked
        returns (uint16 keyIndex)
    {
        require(expiry > _timeNow(), ERR_INVALID_KEY_EXPIRY);

        bytes32 keyPacked = _packPubKey(pubKey);

        Keyring memory keyring = _getOperatorActiveKeyringOrRevert(
            keyringId,
            operator
        );

        require(
            keyring.numAllocKeys >= keyring.numKeys,
            ERR_INSUFFICIENT_ALLOCATION
        );

        bytes32 commitment = getKeyCommitment(pubKey, expiry);

        keyIndex = _totalNumRegisteredKeys;
        keyringIds[keyIndex] = keyringId;

        // Trusted contract - no reentrancy guard needed
        _updateProvidersKeysAndStaticTreeRoots(
            ZERO_VALUE,
            commitment,
            keyIndex,
            proofSiblings
        );

        _totalNumRegisteredKeys = ++keyIndex;

        keyring.numKeys++;
        keyrings[keyringId] = keyring;

        emit KeyRegistered(keyringId, keyIndex, keyPacked, expiry);
    }

    /// @notice Extend the key expiry time. Only the keyring operator may call.
    /// @dev Consider `isAcceptablePubKey` off-chain call before registration.
    function _extendKeyExpiry(
        G1Point memory pubKey,
        uint32 expiry,
        uint32 newExpiry,
        uint16 keyIndex,
        uint16 keyringId,
        bytes32[] memory proofSiblings
    ) private sanitizePubKey(pubKey) whenTreeUnlocked {
        require(
            newExpiry > _timeNow() && newExpiry > expiry,
            ERR_INVALID_KEY_EXPIRY
        );

        bytes32 commitment = getKeyCommitment(pubKey, expiry);
        bytes32 newCommitment = getKeyCommitment(pubKey, newExpiry);

        _updateProvidersKeysAndStaticTreeRoots(
            commitment,
            newCommitment,
            keyIndex,
            proofSiblings
        );

        emit KeyExtended(keyringId, keyIndex, newExpiry);
    }

    /// @notice Update keyring operator. Only the (current) operator may call.
    function _updateKeyringOperator(
        uint16 keyringId,
        address currentoperator,
        address newOperator
    ) private {
        require(newOperator != address(0), ERR_ZERO_OPERATOR_ADDRESS);

        Keyring memory keyring = _getOperatorActiveKeyringOrRevert(
            keyringId,
            currentoperator
        );
        require(newOperator != currentoperator, ERR_SAME_OPERATOR);

        keyring.operator = newOperator;
        keyrings[keyringId] = keyring;

        emit KeyringUpdated(
            keyringId,
            keyring.operator,
            keyring.status,
            keyring.numAllocKeys
        );
    }

    /// @notice Revoke registered key. Either the operator or the owner may call.
    /// @dev It sets the `expiry` to 0, which is an indicator of a revoked key.
    /// Consider `isAcceptablePubKey` off-chain call before registration.
    function _revokeKey(
        address operator,
        uint16 keyringId,
        uint16 keyIndex,
        G1Point memory pubKey,
        uint32 expiry,
        bytes32[] calldata proofSiblings
    ) private sanitizePubKey(pubKey) keyInKeyring(keyIndex, keyringId) {
        Keyring memory keyring = _getActiveKeyringOrRevert(keyringId);

        if (keyring.operator == operator) {
            _requireTreeIsUnlocked();
        } else {
            LibDiamond.enforceOwner();
        }

        bytes32 commitment = getKeyCommitment(pubKey, expiry);

        bytes32 newCommitment = getKeyCommitment(pubKey, REVOKED_KEY_EXPIRY);

        _updateProvidersKeysAndStaticTreeRoots(
            commitment,
            newCommitment,
            keyIndex,
            proofSiblings
        );

        emit KeyRevoked(keyringId, keyIndex);
    }

    function _getNextKeyringId() private view returns (uint16) {
        return _numKeyrings + 1;
    }

    function _getActiveKeyringOrRevert(
        uint16 keyringId
    ) private view returns (Keyring memory keyring) {
        keyring = keyrings[keyringId];

        require(keyring.operator != address(0), ERR_KEYRING_NOT_EXISTS);
        require(keyring.status == STATUS.ACTIVE, ERR_KEYRING_NOT_ACTIVATED);
    }

    function _getOperatorActiveKeyringOrRevert(
        uint16 keyringId,
        address operator
    ) private view returns (Keyring memory keyring) {
        keyring = _getActiveKeyringOrRevert(keyringId);
        require(keyring.operator == operator, ERR_UNAUTHORIZED_OPERATOR);
    }

    function _suspendKeyring(
        Keyring memory keyring
    ) private pure returns (Keyring memory) {
        keyring.status = STATUS.SUSPENDED;
        return keyring;
    }

    function _getUnusedKeyringAllocation(
        Keyring memory keyring
    ) private pure returns (uint16) {
        return keyring.numAllocKeys - keyring.numKeys;
    }

    function _updateProvidersKeysAndStaticTreeRoots(
        bytes32 leaf,
        bytes32 newLeaf,
        uint16 keyIndex,
        bytes32[] memory proofSiblings
    ) private {
        require(
            proofSiblings.length == KEYS_TREE_DEPTH,
            ERR_INCORRECT_SIBLINGS_SIZE
        );

        bytes32 updatedRoot = update(
            _currentRoot,
            leaf,
            newLeaf,
            keyIndex,
            proofSiblings
        );

        _currentRoot = updatedRoot;

        _updateStaticRoot(updatedRoot, PROVIDERS_KEYS_STATIC_LEAF_INDEX);
    }

    function _packPubKey(G1Point memory pubKey) private pure returns (bytes32) {
        return BabyJubJub.pointPack(pubKey);
    }

    function _requireTreeIsUnlocked() private view {
        require(_timeNow() >= _treeLockedTillTime, ERR_TREE_IS_LOCKED);
    }

    function _timeNow() private view returns (uint32) {
        // Time comparison accuracy is acceptable
        // slither-disable-next-line timestamp
        return UtilsLib.safe32TimeNow();
    }
}
