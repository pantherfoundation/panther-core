// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../common/ImmutableOwnable.sol";
import "../common/Types.sol";
import "./zAccountsRegistry/blacklistedZAccountIdsTree/BlacklistedZAccountIdsTree.sol";
import "./zAccountsRegistry/ZAccountRegeistrationSignatureVerifier.sol";

import "./interfaces/IPantherPoolV1.sol";
import "./interfaces/IOnboardingRewardController.sol";

/**
 * @title ZAccountsRegistry
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of zAccounts allowed to interact with MASP.
 */
// solhint-disable var-name-mixedcase
contract ZAccountsRegistry is
    ImmutableOwnable,
    BlacklistedZAccountIdsTree,
    ZAccountRegeistrationSignatureVerifier
{
    // The contract is supposed to run behind a proxy DELEGATECALLing it.
    // On upgrades, adjust `__gap` to match changes of the storage layout.
    // slither-disable-next-line shadowing-state unused-state
    uint256[50] private __gap;

    uint8 private constant ZONE_ZACCOUNT_UNDEFINED = 0x00;
    uint8 private constant ZONE_ZACCOUNT_REGISTERED = 0x01;
    uint8 private constant ZONE_ZACCOUNT_ACTIVATED = 0x02;

    IPantherPoolV1 public immutable PANTHER_POOL;
    IOnboardingRewardController public immutable ONBOARDING_REWARD_CONTROLLER;

    struct ZAccount {
        uint224 _unused; // reserved
        uint24 id; // the ZAccount id, starts from 1
        uint8 version; // ZAccount version
        bytes32 pubRootSpendingKey;
        bytes32 pubReadingKey;
    }

    uint256 public zAccountIdTracker;

    mapping(address => bool) public isMasterEoaBlacklisted;
    mapping(bytes32 => bool) public isPubRootSpendingKeyBlacklisted;
    mapping(uint24 => bool) public isZAccountIdBlacklisted;
    mapping(bytes32 => bool) public zoneZAccountNullifier;
    mapping(address => uint8) public zAccountStatus;

    // Mapping from `MasterEoa` to ZAccount (i.e. params of an ZAccount)
    mapping(address => ZAccount) public zAccounts;

    // Mapping from zAccount Id to Eoa
    mapping(uint24 => address) public ids;

    event ZAccountRegistered(address masterEoz, ZAccount zAccount);
    event ZAccountStatusChanged(address masterEoa, uint256 newStatus);
    event BlacklistForZAccountIdUpdated(uint24 zAccountId, bool isBlackListed);
    event BlacklistForMasterEoaUpdated(address masterEoa, bool isBlackListed);
    event BlacklistForPubRootSpendingKeyUpdated(
        bytes32 pubRootSpendingKey,
        bool isBlackListed
    );

    constructor(
        address _owner,
        address pantherPool,
        address onboardingRewardController
    ) ImmutableOwnable(_owner) {
        require(
            pantherPool != address(0) &&
                onboardingRewardController != address(0),
            "Init: Zero address"
        );

        PANTHER_POOL = IPantherPoolV1(pantherPool);
        ONBOARDING_REWARD_CONTROLLER = IOnboardingRewardController(
            onboardingRewardController
        );
    }

    /* ========== VIEW FUNCTIONS ========== */

    function isZAccountBlacklisted(address _masterEOA)
        external
        view
        returns (bool)
    {
        ZAccount memory _ZAccount = zAccounts[_masterEOA];

        bytes32 pubRootSpendingKey = _ZAccount.pubRootSpendingKey;
        uint24 zAccountId = _ZAccount.id;

        return
            isPubRootSpendingKeyBlacklisted[pubRootSpendingKey] ||
            isMasterEoaBlacklisted[_masterEOA] ||
            isZAccountIdBlacklisted[zAccountId];
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function registerZAccount(
        bytes32 _pubRootSpendingKey,
        bytes32 _pubReadingKey,
        bytes32 _salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(
            !isPubRootSpendingKeyBlacklisted[_pubRootSpendingKey],
            "ZAR: Blacklisted pub root spending key"
        );

        bytes32 hash = toTypedMessageHash(
            _salt,
            _pubRootSpendingKey,
            _pubReadingKey
        );

        address masterEoa = verifySignature(hash, v, r, s);
        require(
            !isMasterEoaBlacklisted[masterEoa],
            "ZAR: Blacklisted master eoa"
        );
        require(
            zAccountStatus[masterEoa] == ZONE_ZACCOUNT_UNDEFINED,
            "ZAR: zAccount exists"
        );

        uint24 zAccountId = uint24(_getNextZAccountId());

        ZAccount memory _ZAccount = ZAccount({
            _unused: uint224(0),
            id: zAccountId,
            version: ZACCOUNT_VERSION,
            pubRootSpendingKey: _pubRootSpendingKey,
            pubReadingKey: _pubReadingKey
        });

        ids[zAccountId] = masterEoa;
        zAccounts[masterEoa] = _ZAccount;
        zAccountStatus[masterEoa] = ZONE_ZACCOUNT_REGISTERED;

        emit ZAccountRegistered(masterEoa, _ZAccount);
    }

    // extraInputsHash,                       // [1]
    // zkpAmount,                             // [2]
    // zkpChange,                             // [3]
    // zAccountId,                            // [4]
    // zAccountPrpAmount,                     // [5]
    // zAccountCreateTime,                    // [6]
    // zAccountRootSpendPubKey,               // [7] - x,y = 2
    // zAccountMasterEOA,                     // [8]
    // zAccountNullifier,                     // [9]
    // zAccountCommitment,                    // [10]
    // kycSignedMessageHash,                  // [11]
    // forestMerkleRoot,                      // [12]
    // saltHash,                              // [13]
    // magicalConstraint                      // [14]
    function activateZAccount(
        uint256[14] calldata inputs,
        uint256 secret,
        SnarkProof calldata proof
    ) external {
        uint256 zAccountId = inputs[3];
        address userMasterEoa = address(uint160(inputs[7]));

        require(ids[uint24(zAccountId)] == userMasterEoa, "ZAR: Not exist");

        require(
            !isPubRootSpendingKeyBlacklisted[bytes32(inputs[6])],
            "ZAR: Blacklisted pub root spending key"
        );
        require(
            !isMasterEoaBlacklisted[userMasterEoa],
            "ZAR: Blacklisted master eoa"
        );
        require(
            !isZAccountIdBlacklisted[uint24(inputs[3])],
            "ZAR: Blacklisted zAccount id"
        );

        // Prevent activating twice for one zone
        require(
            !zoneZAccountNullifier[bytes32(inputs[8])],
            "ZAR: nullifier exists"
        );
        zoneZAccountNullifier[bytes32(inputs[8])] = true;

        // If status is activated, it means  Zaccount is activated at least in 1 zone.
        if (zAccountStatus[userMasterEoa] == ZONE_ZACCOUNT_REGISTERED)
            zAccountStatus[userMasterEoa] = ZONE_ZACCOUNT_ACTIVATED;

        _grantZkpRewardsToUserAndKycProvider(
            inputs[1], // zkpAmount
            userMasterEoa,
            address(0) // kycProvider address???
        );

        _createZAccountUTXO(inputs, secret, proof);

        emit ZAccountStatusChanged(
            userMasterEoa,
            uint256(ZONE_ZACCOUNT_ACTIVATED)
        );
    }

    function _grantZkpRewardsToUserAndKycProvider(
        uint256 _userZkpReward,
        address _user,
        address _kycProvider
    ) internal {
        uint256 _userZkpRewardAlloc = ONBOARDING_REWARD_CONTROLLER.grantRewards(
            _user,
            _kycProvider
        );

        require(_userZkpRewardAlloc == _userZkpReward);
    }

    /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    // maybe batch
    function updateBlacklistForMasterEoa(address masterEoa, bool isBlackListed)
        external
        onlyOwner
    {
        require(
            isMasterEoaBlacklisted[masterEoa] != isBlackListed,
            "ZAR: Invalid master eoa status"
        );

        isMasterEoaBlacklisted[masterEoa] = isBlackListed;

        emit BlacklistForMasterEoaUpdated(masterEoa, isBlackListed);
    }

    // maybe batch
    function updateBlacklistForPubRootSpendingKey(
        bytes32 pubRootSpendingKey,
        bool isBlackListed
    ) external onlyOwner {
        require(
            isPubRootSpendingKeyBlacklisted[pubRootSpendingKey] !=
                isBlackListed,
            "ZAR: Invalid pub root spending key status"
        );

        isPubRootSpendingKeyBlacklisted[pubRootSpendingKey] = isBlackListed;

        emit BlacklistForPubRootSpendingKeyUpdated(
            pubRootSpendingKey,
            isBlackListed
        );
    }

    function updateBlacklistForZAccountId(
        uint24 zAccountId,
        bytes32 leaf,
        bytes32[] calldata proofSiblings,
        bool isBlacklisted
    ) public onlyOwner {
        require(ids[zAccountId] != address(0), "ZAR: not exists");
        require(isZAccountIdBlacklisted[zAccountId] != isBlacklisted, "");

        if (isBlacklisted) {
            _addBlacklistZAccountId(zAccountId, leaf, proofSiblings);
        } else {
            _removeBlacklistZAccountId(zAccountId, leaf, proofSiblings);
        }

        isZAccountIdBlacklisted[zAccountId] = isBlacklisted;

        emit BlacklistForZAccountIdUpdated(zAccountId, isBlacklisted);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _createZAccountUTXO(
        uint256[14] calldata inputs,
        uint256 secret,
        SnarkProof calldata proof
    ) private {
        // Pool is supposed to revert in case of any error
        // solhint-disable-next-line no-empty-blocks
        try PANTHER_POOL.createUtxo(inputs, secret, proof) {} catch Error(
            string memory reason
        ) {
            revert(reason);
        }
    }

    function _getNextZAccountId() internal returns (uint256 nextId) {
        nextId = zAccountIdTracker + 1;

        if (nextId & zACCOUNT_ID_MAX_RANGE == zACCOUNT_ID_MAX_RANGE)
            zAccountIdTracker = nextId + zACCOUNT_ID_JUMP_COUNT;
        else zAccountIdTracker = nextId;
    }
}

/**

 * pubKeyBlacklist: mapping (key => bool)
 * masterEoaBlacklist: mapping (address => bool)
 *
 * masterEoaBlacklist: on blacklist via Id/Eoa, this mapping will be updated
 * problem: by reading the mapping, we do not know which method has been used for blacklisting.
 * solution: we can read event to check if user is blacklisted by id or eoa
 *
 * 
 * Info: it was not a good idea. because:
 *  1. both `updateBlacklistForMasterEoa` and `updateBlacklistForZAccountId` updated `masterEoaBlacklist` mapping.
 *  2. We may remove the master EOA from `masterEoaBlacklist` mapping by calling `updateBlacklistForMasterEoa(address, false)`
 *  3. it means, according to `masterEoaBlacklist` mapping, the eoa is not blacklisted BUT the 
 *     id is still be in the blacklisted merkle tree.
 *     so, the contract consider the user as non-blacklisted.
 *     It's better to have 3 mapping to keep track of all the blacklisted PublicKeys, EOAs and IDs.  
 * 
 *  
 */
