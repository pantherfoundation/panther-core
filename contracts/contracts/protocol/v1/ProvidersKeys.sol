// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./pantherForest/interfaces/ITreeRootGetter.sol";
import "./pantherForest/interfaces/ITreeRootUpdater.sol";

import "../../common/UtilsLib.sol";
import "../../common/crypto/BabyJubJub.sol";
import "../../common/crypto/PoseidonHashers.sol";
import "./errMsgs/ProvidersKeysErrMsgs.sol";

import "./providersKeys/ProvidersKeysSignatureVerifier.sol";
import "./pantherForest/merkleTrees/BinaryUpdatableTree.sol";
import { PROVIDERS_KEYS_STATIC_LEAF_INDEX } from "./pantherForest/Constants.sol";
import { SIXTEEN_LEVELS, SIXTEEN_LEVEL_EMPTY_TREE_ROOT, ZERO_VALUE } from "./pantherForest/zeroTrees/Constants.sol";

import "../../common/ImmutableOwnable.sol";
import { G1Point } from "../../common/Types.sol";

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
contract ProvidersKeys is
    ProvidersKeysSignatureVerifier,
    BinaryUpdatableTree,
    ImmutableOwnable,
    ITreeRootGetter
{
    // solhint-disable var-name-mixedcase
    // TODO add `constant` label to these variables
    uint256 private KEYS_TREE_DEPTH = SIXTEEN_LEVELS;
    uint16 private constant MAX_KEYS = uint16(2 ** SIXTEEN_LEVELS - 1);

    uint32 private REVOKED_KEY_EXPIRY = 0;
    uint256 private MAX_TREE_LOCK_PERIOD = 30 days;

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
    bytes32 private _treeRoot;

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
        address _owner,
        uint8 keyringVersion,
        address pantherStaticTree
    ) ImmutableOwnable(_owner) ProvidersKeysSignatureVerifier(keyringVersion) {
        require(pantherStaticTree != address(0), ERR_INIT_CONTRACT);

        // trusted contract - no reentrancy guard needed
        // slither-disable-next-line unchecked-transfer,reentrancy-events
        PANTHER_STATIC_TREE = ITreeRootUpdater(pantherStaticTree);
    }

    modifier whenTreeUnlocked() {
        _requireTreeIsUnlocked();
        _;
    }

    modifier keyInKeyring(uint16 keyIndex, uint16 keyringId) {
        require(keyringIds[keyIndex] == keyringId, ERR_KEY_IS_NOT_IN_KEYRING);
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

    function getRoot() external view returns (bytes32) {
        return _treeRoot == bytes32(0) ? zeroRoot() : _treeRoot;
    }

    // @dev It does NOT check if the pubKey is a point on the BabyJubJub curve
    function packPubKey(G1Point memory pubKey) public pure returns (bytes32) {
        // Coordinates must be in the SNARK field
        require(
            BabyJubJub.isG1PointLowerThanFieldSize([pubKey.x, pubKey.y]),
            ERR_NOT_IN_FIELD
        );
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

    /// @notice Register a public key. Only the keyring operator may call.
    function registerKey(
        uint16 keyringId,
        G1Point memory pubKey,
        uint32 expiry,
        bytes32[] memory proofSiblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenTreeUnlocked returns (uint16 keyIndex) {
        require(expiry > _timeNow(), ERR_INVALID_KEY_EXPIRY);

        bytes32 keyPacked = BabyJubJub.pointPack(pubKey);
        address operator = recoverOperator(
            keyringId,
            keyPacked,
            expiry,
            v,
            r,
            s
        );

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
    function extendKeyExpiry(
        G1Point memory pubKey,
        uint32 expiry,
        uint32 newExpiry,
        uint16 keyIndex,
        bytes32[] memory proofSiblings
    ) external whenTreeUnlocked {
        require(
            newExpiry > _timeNow() && newExpiry > expiry,
            ERR_INVALID_KEY_EXPIRY
        );
        uint16 keyringId = keyringIds[keyIndex];
        _getOperatorActiveKeyringOrRevert(keyringId, msg.sender);

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
    function updateKeyringOperator(
        uint16 keyringId,
        address newOperator
    ) external {
        require(newOperator != address(0), ERR_ZERO_OPERATOR_ADDRESS);

        Keyring memory keyring = _getOperatorActiveKeyringOrRevert(
            keyringId,
            msg.sender
        );
        require(newOperator != msg.sender, ERR_SAME_OPERATOR);

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
    function revokeKey(
        uint16 keyringId,
        uint16 keyIndex,
        G1Point memory pubKey,
        uint32 expiry,
        bytes32[] calldata proofSiblings
    ) external keyInKeyring(keyIndex, keyringId) {
        Keyring memory keyring = _getActiveKeyringOrRevert(keyringId);

        if (keyring.operator == msg.sender) {
            _requireTreeIsUnlocked();
        } else {
            require(OWNER == msg.sender, ERR_UNAUTHORIZED_OPERATOR);
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

    function hash(
        bytes32[2] memory input
    ) internal pure override returns (bytes32) {
        // Next call reverts if the input is not in the SNARK field
        return PoseidonHashers.poseidonT3(input);
    }

    function zeroRoot() internal pure override returns (bytes32) {
        return SIXTEEN_LEVEL_EMPTY_TREE_ROOT;
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
            _treeRoot,
            leaf,
            newLeaf,
            keyIndex,
            proofSiblings
        );

        _treeRoot = updatedRoot;

        // trusted contract - no reentrancy guard needed
        // slither-disable-next-line unchecked-transfer,reentrancy-events
        PANTHER_STATIC_TREE.updateRoot(
            updatedRoot,
            PROVIDERS_KEYS_STATIC_LEAF_INDEX
        );
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
