// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import { PoseidonT4, PoseidonT3 } from "./crypto/Poseidon.sol";
import { FIELD_SIZE } from "./crypto/SnarkConstants.sol";
import { ZERO_VALUE } from "./pantherForest/zeroTrees/Constants.sol";

import "../common/ImmutableOwnable.sol";

import "./pantherForest/merkleTrees/BinaryUpdatableTree.sol";

contract AccountProvidersKeys is ImmutableOwnable, BinaryUpdatableTree {
    uint8 constant VERSION = 0x01;
    uint32 constant MAX_LEAVES = 65536;

    /// @notice statuses for account providers
    enum STATUS {
        UNDEFINED,
        ACTIVE,
        SUSPENDED
    }

    struct ProviderAccount {
        address operator;
        uint8 id;
        STATUS status;
        uint16 usedLeaves;
        uint16 allocLeaves;
        uint32 registrationBlockNum;
        uint16 _unused;
    }

    /// @notice Provider ID -> Leaf index
    mapping(uint32 => uint8) _leafOwners;

    /// @notice Mapping from operator to ProviderAccount
    mapping(address => ProviderAccount) _providerAccount;

    uint16 private _providersCounter;
    uint32 private _totalUsedLeaves;
    uint32 private _totalAllocatedLeaves;
    bool public isPubKeyRegistrationExecutable;

    bytes32 public currentRoot;

    event ProviderAccountOperatorUpdated(
        address oldOperator,
        address newOperator,
        STATUS status
    );
    event PubKeyRegistered(
        uint8 id,
        uint256 leafIndex,
        uint256 pubSpendingKeyX,
        uint256 pubSpendingKeyY
    );
    event PubKeyRegistrationExecutabilityChanged(bool isExecutable);

    constructor(address _owner) ImmutableOwnable(_owner) {}

    function getNextProviderId() public view returns (uint16) {
        return _providersCounter + 1;
    }

    function getAccountProviderOrRevert(address account)
        public
        view
        returns (ProviderAccount memory)
    {
        ProviderAccount memory providerAccount = _providerAccount[account];
        require(
            _isTrsutProviderExistsAndActive(providerAccount),
            "TPK: Trust provider is suspended or not exists"
        );
        return providerAccount;
    }

    function getPubKeyCommitment(
        uint256 pubSpendingKeyX,
        uint256 pubSpendingKeyY,
        uint32 expiryDate
    ) public pure returns (bytes32 commitment) {
        commitment = PoseidonT4.poseidon(
            [
                bytes32(pubSpendingKeyX),
                bytes32(pubSpendingKeyY),
                bytes32(uint256(expiryDate) | uint256(VERSION))
            ]
        );
    }

    function registerPubKey(
        uint256 pubSpendingKeyX,
        uint256 pubSpendingKeyY,
        uint32 expiryDate,
        bytes32[] memory proofSiblings
    ) external {
        require(
            isPubKeyRegistrationExecutable,
            "TPK: Registration is not executable"
        );
        ProviderAccount memory providerAccount = getAccountProviderOrRevert(
            msg.sender
        );

        require(expiryDate > block.timestamp, "TPK: Invalid expiry date");
        require(
            providerAccount.allocLeaves > providerAccount.usedLeaves,
            "TPK: Out of space"
        ); // TODO: Why >, not >=

        require(
            pubSpendingKeyX <= FIELD_SIZE && pubSpendingKeyY <= FIELD_SIZE,
            "TPK: PubKey not in Field"
        );

        bytes32 commitment = getPubKeyCommitment(
            pubSpendingKeyX,
            pubSpendingKeyY,
            expiryDate
        );

        uint32 leafIndex = _totalUsedLeaves;
        _leafOwners[leafIndex] = providerAccount.id;

        currentRoot = update(
            currentRoot,
            ZERO_VALUE,
            commitment,
            leafIndex,
            proofSiblings
        );
        leafIndex++;
        _totalUsedLeaves = leafIndex;

        providerAccount.usedLeaves++;
        _providerAccount[msg.sender] = providerAccount;

        emit PubKeyRegistered(
            providerAccount.id,
            leafIndex,
            pubSpendingKeyX,
            pubSpendingKeyY
        );
    }

    function extendPubKeyExpiryDate(
        uint8 providerId,
        uint256 pubSpendingKeyX,
        uint256 pubSpendingKeyY,
        uint32 expiryDate,
        uint32 newExpiryDate,
        uint32 leafIndex,
        bytes32[] memory proofSiblings
    ) external {
        require(expiryDate > 0, "");

        bytes32 commitment = getPubKeyCommitment(
            pubSpendingKeyX,
            pubSpendingKeyY,
            expiryDate
        );
        bytes32 newCommitment = getPubKeyCommitment(
            pubSpendingKeyX,
            pubSpendingKeyY,
            newExpiryDate
        );

        currentRoot = update(
            currentRoot,
            commitment,
            newCommitment,
            leafIndex,
            proofSiblings
        );
    }

    function updateAccountProviderOperator(address newOperator) external {
        require(newOperator != address(0), "TPK: Zero account");

        ProviderAccount memory providerAccount = getAccountProviderOrRevert(
            msg.sender
        );
        address oldOperator = providerAccount.operator;
        require(newOperator != oldOperator, "TPK: Zero account");

        _providerAccount[newOperator] = providerAccount;
        _providerAccount[msg.sender] = _resetAccountProvider(providerAccount);

        emit ProviderAccountOperatorUpdated(
            oldOperator,
            newOperator,
            STATUS.ACTIVE
        );
    }

    function puasePubKeyRegistration() external onlyOwner {
        require(!isPubKeyRegistrationExecutable, "TPK: Already executable");
        isPubKeyRegistrationExecutable = true;

        emit PubKeyRegistrationExecutabilityChanged(true);
    }

    function unPausePubKeyRegistration() external onlyOwner {
        require(isPubKeyRegistrationExecutable, "TPK: Already non executable");
        isPubKeyRegistrationExecutable = false;

        emit PubKeyRegistrationExecutabilityChanged(false);
    }

    /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    function addAccountProvider(address operator, uint16 allocLeaves)
        external
        onlyOwner
    {
        ProviderAccount memory providerAccount = _providerAccount[operator];
        require(providerAccount.id == 0, "TPK: Trust provider exists");
        uint32 filledLeaves = _totalAllocatedLeaves;

        filledLeaves += allocLeaves;
        require(MAX_LEAVES >= filledLeaves, "TPK: High allocated keys");

        uint16 providerId = getNextProviderId();

        providerAccount = ProviderAccount({
            operator: operator,
            id: uint8(providerId),
            status: STATUS.ACTIVE,
            usedLeaves: 0,
            allocLeaves: uint16(allocLeaves),
            registrationBlockNum: uint32(block.number),
            _unused: 0
        });

        _providerAccount[operator] = providerAccount;
        _providersCounter = providerId;
        _totalAllocatedLeaves = filledLeaves;

        emit ProviderAccountOperatorUpdated(
            address(0),
            operator,
            STATUS.ACTIVE
        );
    }

    function suspendAccountProvider(address account) external onlyOwner {
        ProviderAccount memory providerAccount = getAccountProviderOrRevert(
            account
        );

        // subtract the unused leaves from filled leaves
        _totalAllocatedLeaves -= _getProviderUnusedLeaves(providerAccount);

        _providerAccount[account] = _suspendAccountProvider(providerAccount);

        emit ProviderAccountOperatorUpdated(account, account, STATUS.SUSPENDED);
    }

    function activeAccountProvider(address account) external onlyOwner {
        ProviderAccount memory providerAccount = _providerAccount[account];
        require(
            providerAccount.status == STATUS.SUSPENDED,
            "TPK: Already resumed"
        );
        uint32 filledLeaves = _totalAllocatedLeaves;
        // Unused allocation before suspanding. To be allocated again.
        uint32 providerUnUsedLeaves = _getProviderUnusedLeaves(providerAccount);
        filledLeaves += providerUnUsedLeaves;

        // When there is not enough empty leaves to give back to provider
        if (filledLeaves > MAX_LEAVES) {
            providerUnUsedLeaves = MAX_LEAVES - filledLeaves;
            filledLeaves = MAX_LEAVES;
        }

        providerAccount.status = STATUS.ACTIVE;
        _totalAllocatedLeaves = filledLeaves;

        emit ProviderAccountOperatorUpdated(account, account, STATUS.ACTIVE);
    }

    function extendPublicKeyAllocation(address account, uint16 allocation)
        external
        onlyOwner
    {
        ProviderAccount memory providerAccount = getAccountProviderOrRevert(
            account
        );
        uint32 filledLeaves = _totalAllocatedLeaves;
        filledLeaves += allocation;
        require(MAX_LEAVES >= filledLeaves, "TPK: High allocated keys");

        uint16 newAccountProviderAllocation = providerAccount.allocLeaves +
            allocation;
        _providerAccount[account].allocLeaves = newAccountProviderAllocation;
        _totalAllocatedLeaves = filledLeaves;
    }

    function revokePublicKey(
        uint256 pubSpendingKeyX,
        uint256 pubSpendingKeyY,
        uint32 expiryDate,
        uint256 leafIndex,
        bytes32[] calldata proofSiblings
    ) external onlyOwner {
        bytes32 commitment = getPubKeyCommitment(
            pubSpendingKeyX,
            pubSpendingKeyY,
            expiryDate
        );

        bytes32 newCommitment = PoseidonT4.poseidon(
            [
                bytes32(pubSpendingKeyX),
                bytes32(pubSpendingKeyY),
                bytes32(uint256(0))
            ]
        );

        currentRoot = update(
            currentRoot,
            commitment,
            newCommitment,
            leafIndex,
            proofSiblings
        );
    }

    /* ========== INTERNAL & PRIVATE FUNCTIONS ========== */

    function _suspendAccountProvider(ProviderAccount memory providerAccount)
        private
        pure
        returns (ProviderAccount memory)
    {
        providerAccount.status = STATUS.SUSPENDED;

        return providerAccount;
    }

    function _resetAccountProvider(ProviderAccount memory providerAccount)
        private
        pure
        returns (ProviderAccount memory)
    {
        providerAccount = ProviderAccount({
            operator: address(0),
            id: 0,
            status: STATUS.UNDEFINED,
            usedLeaves: 0,
            allocLeaves: 0,
            registrationBlockNum: 0,
            _unused: 0
        });

        return providerAccount;
    }

    function _isTrsutProviderExistsAndActive(
        ProviderAccount memory providerAccount
    ) private pure returns (bool) {
        return
            providerAccount.id != 0 && providerAccount.status == STATUS.ACTIVE;
    }

    function _getProviderUnusedLeaves(ProviderAccount memory providerAccount)
        internal
        returns (uint16)
    {
        return providerAccount.allocLeaves - providerAccount.usedLeaves;
    }

    function hash(bytes32[2] memory input)
        internal
        pure
        override
        returns (bytes32)
    {
        require(
            uint256(input[0]) < FIELD_SIZE && uint256(input[1]) < FIELD_SIZE,
            "BT:TOO_LARGE_LEAF_INPUT"
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
