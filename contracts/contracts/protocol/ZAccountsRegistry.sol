// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "./interfaces/IOnboardingController.sol";
import "./interfaces/IPantherPoolV1.sol";
import "./pantherForest/interfaces/ITreeRootUpdater.sol";

import "./crypto/BabyJubJub.sol";

import "./zAccountsRegistry/BlacklistedZAccountIdsTree.sol";
import "./zAccountsRegistry/ZAccountsRegeistrationSignatureVerifier.sol";

import "../common/ImmutableOwnable.sol";
import "../common/Types.sol";
import { ZACCOUNT_BLACKLIST_STATIC_LEAF_INDEX } from "./pantherForest/Constant.sol";

/**
 * @title ZAccountsRegistry
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of zAccounts allowed to interact with MASP.
 */

// solhint-disable contract-name-camelcase
contract ZAccountsRegistry is
    ImmutableOwnable,
    BlacklistedZAccountIdsTree,
    ZAccountsRegeistrationSignatureVerifier
{
    // The contract is supposed to run behind a proxy DELEGATECALLing it.
    // On upgrades, adjust `__gap` to match changes of the storage layout.
    // slither-disable-next-line shadowing-state unused-state
    uint256[50] private __gap;

    enum ZACCOUNT_STATUS {
        UNDEFINED,
        REGISTERED,
        ACTIVATED
    }
    // solhint-disable var-name-mixedcase

    uint256 private constant ZACCOUNT_ID_COUNTER_JUMP = 2;

    IPantherPoolV1 public immutable PANTHER_POOL;
    ITreeRootUpdater public immutable PANTHER_STATIC_TREE;
    IOnboardingController public immutable ONBOARDING_CONTROLLER;

    // solhint-enable var-name-mixedcase

    struct ZAccount {
        uint224 _unused; // reserved
        uint24 id; // the ZAccount id, starts from 0
        uint8 version; // ZAccount version
        bytes32 pubRootSpendingKey;
        bytes32 pubReadingKey;
    }

    uint256 public zAccountIdTracker;

    mapping(bytes32 => uint256) public zoneZAccountNullifiers;
    mapping(address => ZACCOUNT_STATUS) public zAccountStatus;
    mapping(address => bool) public isMasterEoaBlacklisted;
    mapping(bytes32 => bool) public isPubRootSpendingKeyBlacklisted;
    mapping(uint24 => bool) public isZAccountIdBlacklisted;

    // Mapping from `MasterEoa` to ZAccount (i.e. params of an ZAccount)
    mapping(address => ZAccount) public zAccounts;

    // Mapping from zAccount Id to Master Eoa
    mapping(uint24 => address) public masterEOAs;

    event ZAccountRegistered(address masterEoa, ZAccount zAccount);
    event ZAccountActivated(uint24 id);
    event BlacklistForZAccountIdUpdated(uint24 zAccountId, bool isBlackListed);
    event BlacklistForMasterEoaUpdated(address masterEoa, bool isBlackListed);
    event BlacklistForPubRootSpendingKeyUpdated(
        bytes32 packedPubRootSpendingKey,
        bool isBlackListed
    );

    constructor(
        address _owner,
        uint8 _zAccountVersion,
        address pantherPool,
        address pantherStaticTree,
        address onboardingController
    )
        ImmutableOwnable(_owner)
        ZAccountsRegeistrationSignatureVerifier(_zAccountVersion)
    {
        require(
            pantherPool != address(0) &&
                pantherStaticTree != address(0) &&
                onboardingController != address(0),
            ERR_INIT_CONTRACT
        );

        PANTHER_POOL = IPantherPoolV1(pantherPool);
        PANTHER_STATIC_TREE = ITreeRootUpdater(pantherStaticTree);
        ONBOARDING_CONTROLLER = IOnboardingController(onboardingController);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function isZAccountWhitelisted(address _masterEOA)
        external
        view
        returns (bool isWhitelisted)
    {
        ZAccount memory _zAccount = zAccounts[_masterEOA];

        bool isZAccountExists = masterEOAs[_zAccount.id] != address(0);

        (bool isBlacklisted, ) = _isBlacklisted(
            _zAccount.id,
            _masterEOA,
            _zAccount.pubRootSpendingKey
        );

        return isZAccountExists && !isBlacklisted;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function registerZAccount(
        G1Point memory _pubRootSpendingKey,
        G1Point memory _pubReadingKey,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 pubRootSpendingKeyPacked = BabyJubJub.pointPack(
            _pubRootSpendingKey
        );
        bytes32 pubReadingKeyPacked = BabyJubJub.pointPack(_pubReadingKey);

        require(
            !isPubRootSpendingKeyBlacklisted[pubRootSpendingKeyPacked],
            ERR_BLACKLIST_PUB_ROOT_SPENDING_KEY
        );

        address masterEoa = recoverMasterEoa(
            pubRootSpendingKeyPacked,
            pubReadingKeyPacked,
            v,
            r,
            s
        );

        require(!isMasterEoaBlacklisted[masterEoa], ERR_BLACKLIST_MASTER_EOA);
        require(
            zAccountStatus[masterEoa] == ZACCOUNT_STATUS.UNDEFINED,
            ERR_DUPLICATED_MASTER_EOA
        );

        uint24 zAccountId = uint24(_getNextZAccountId());

        ZAccount memory _zAccount = ZAccount({
            _unused: uint224(0),
            id: zAccountId,
            version: uint8(ZACCOUNT_VERSION),
            pubRootSpendingKey: pubRootSpendingKeyPacked,
            pubReadingKey: pubReadingKeyPacked
        });

        masterEOAs[zAccountId] = masterEoa;
        zAccounts[masterEoa] = _zAccount;
        zAccountStatus[masterEoa] = ZACCOUNT_STATUS.REGISTERED;

        emit ZAccountRegistered(masterEoa, _zAccount);
    }

    function activateZAccount(
        uint256[] calldata inputs,
        bytes memory secretMessage,
        SnarkProof calldata proof,
        uint8 forestHistoryRootIndex
    ) external {
        (
            bytes32 extraInputsHash,
            uint256 zkpAmount,
            uint24 zAccountId,
            ,
            bytes32 zAccountRootSpendPubKey,
            address zAccountMasterEOA,
            bytes32 zAccountNullifier,
            ,

        ) = _destructPublicInputs(inputs);
        {
            require(
                extraInputsHash == keccak256(secretMessage),
                ERR_INVALID_EXTRA_INPUT_HASH
            );
            require(
                masterEOAs[zAccountId] == zAccountMasterEOA,
                ERR_UNKNOWN_ZACCOUNT
            );

            (bool isBlacklisted, string memory errMsg) = _isBlacklisted(
                zAccountId,
                zAccountMasterEOA,
                zAccountRootSpendPubKey
            );
            require(!isBlacklisted, errMsg);

            // Prevent activating twice for same zone or same network
            require(
                zoneZAccountNullifiers[zAccountNullifier] == 0,
                ERR_DUPLICATED_NULLIFIER
            );

            zoneZAccountNullifiers[zAccountNullifier] = block.number;

            ZACCOUNT_STATUS userPrevStatus = zAccountStatus[zAccountMasterEOA];

            // if the status is registered, then change it to activate.
            // If status is already activated, it means  Zaccount is activated at least in 1 zone.
            if (userPrevStatus == ZACCOUNT_STATUS.REGISTERED) {
                zAccountStatus[zAccountMasterEOA] = ZACCOUNT_STATUS.ACTIVATED;
            }

            uint256 _zkpRewards = _notifyOnboardingController(
                zAccountMasterEOA,
                uint8(userPrevStatus),
                uint8(ZACCOUNT_STATUS.ACTIVATED),
                new bytes(0)
            );

            require(_zkpRewards == zkpAmount, ERR_LOW_ZKP_AMOUNT);
        }

        _createZAccountUTXO(
            inputs,
            proof,
            secretMessage,
            forestHistoryRootIndex
        );

        emit ZAccountActivated(zAccountId);
    }

    // /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    function batchUpdateBlacklistForMasterEoa(
        address[] calldata masterEoas,
        bool[] calldata isBlackListed
    ) external onlyOwner {
        require(
            masterEoas.length == isBlackListed.length,
            ERR_MISMATCH_ARRAYS_LENGTH
        );

        for (uint256 i = 0; i < masterEoas.length; ) {
            require(
                isMasterEoaBlacklisted[masterEoas[i]] != isBlackListed[i],
                ERR_REPETITIVE_STATUS
            );

            isMasterEoaBlacklisted[masterEoas[i]] = isBlackListed[i];

            emit BlacklistForMasterEoaUpdated(masterEoas[i], isBlackListed[i]);

            unchecked {
                ++i;
            }
        }
    }

    function batchUpdateBlacklistForPubRootSpendingKey(
        bytes32[] calldata packedPubRootSpendingKeys,
        bool[] calldata isBlackListed
    ) external onlyOwner {
        require(
            packedPubRootSpendingKeys.length == isBlackListed.length,
            ERR_MISMATCH_ARRAYS_LENGTH
        );

        for (uint256 i = 0; i < packedPubRootSpendingKeys.length; ) {
            require(
                isPubRootSpendingKeyBlacklisted[packedPubRootSpendingKeys[i]] !=
                    isBlackListed[i],
                ERR_REPETITIVE_STATUS
            );

            isPubRootSpendingKeyBlacklisted[
                packedPubRootSpendingKeys[i]
            ] = isBlackListed[i];

            emit BlacklistForPubRootSpendingKeyUpdated(
                packedPubRootSpendingKeys[i],
                isBlackListed[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    function updateBlacklistForZAccountId(
        uint24 zAccountId,
        bytes32 leaf,
        bytes32[] calldata proofSiblings,
        bool isBlacklisted
    ) public onlyOwner {
        require(masterEOAs[zAccountId] != address(0), ERR_UNKNOWN_ZACCOUNT);
        require(
            isZAccountIdBlacklisted[zAccountId] != isBlacklisted,
            ERR_REPETITIVE_STATUS
        );

        bytes32 blacklistedZAccountIdsTreeRoot;

        if (isBlacklisted) {
            blacklistedZAccountIdsTreeRoot = _addZAccountIdToBlacklist(
                zAccountId,
                leaf,
                proofSiblings
            );
        } else {
            blacklistedZAccountIdsTreeRoot = _removeZAccountIdFromBlacklist(
                zAccountId,
                leaf,
                proofSiblings
            );
        }

        isZAccountIdBlacklisted[zAccountId] = isBlacklisted;

        PANTHER_STATIC_TREE.updateRoot(
            blacklistedZAccountIdsTreeRoot,
            ZACCOUNT_BLACKLIST_STATIC_LEAF_INDEX
        );

        emit BlacklistForZAccountIdUpdated(zAccountId, isBlacklisted);
    }

    // /* ========== PRIVATE FUNCTIONS ========== */

    function _getNextZAccountId() internal returns (uint256 curId) {
        curId = zAccountIdTracker;
        zAccountIdTracker = curId & 0xFF < 254
            ? curId + 1
            : curId + ZACCOUNT_ID_COUNTER_JUMP;
    }

    function _createZAccountUTXO(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        bytes memory secretMessage,
        uint8 forestHistoryRootIndex
    ) private returns (uint256) {
        // Pool is supposed to revert in case of any error
        try
            PANTHER_POOL.createZAccountUtxo(
                inputs,
                proof,
                secretMessage,
                forestHistoryRootIndex
            )
        returns (uint256 result) {
            return result;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _notifyOnboardingController(
        address _user,
        uint8 _prevStatus,
        uint8 _newStatus,
        bytes memory _data
    ) private returns (uint256 _zkpRewards) {
        _zkpRewards = ONBOARDING_CONTROLLER.grantRewards(
            _user,
            _prevStatus,
            _newStatus,
            _data
        );
    }

    // extraInputsHash,                       // [1]
    // zkpAmount,                             // [2]
    // zkpChange,                             // [3]
    // zAccountId,                            // [4]
    // zAccountPrpAmount,                     // [5]
    // zAccountCreateTime,                    // [6]
    // zAccountRootSpendPubKeyX,              // [7]
    // zAccountRootSpendPubKeyY,              // [8]
    // zAccountMasterEOA,                     // [9]
    // zAccountNullifier,                     // [10]
    // zAccountCommitment,                    // [12]
    // kycSignedMessageHash,                  // [12]
    // forestMerkleRoot,                      // [13]
    // saltHash,                              // [14]
    // magicalConstraint                      // [15]
    function _destructPublicInputs(uint256[] memory inputs)
        private
        pure
        returns (
            bytes32 extraInputsHash,
            uint256 zkpAmount,
            uint24 zAccountId,
            uint256 zAccountPrpAmount,
            bytes32 zAccountRootSpendPubKey,
            address zAccountMasterEOA,
            bytes32 zAccountNullifier,
            uint256 zAccountCommitment,
            uint256 kycSignedMessageHash
        )
    {
        extraInputsHash = bytes32(inputs[0]);
        zkpAmount = inputs[1];
        zAccountId = uint24(inputs[3]);
        zAccountPrpAmount = inputs[4];

        zAccountRootSpendPubKey = BabyJubJub.pointPack(
            G1Point({ x: inputs[6], y: inputs[7] })
        );

        zAccountMasterEOA = address(uint160(inputs[8]));
        zAccountNullifier = bytes32(inputs[9]);
        zAccountCommitment = inputs[10];
        kycSignedMessageHash = inputs[11];
    }

    function _isBlacklisted(
        uint24 id,
        address _masterEOA,
        bytes32 pubRootSpendingKey
    ) private view returns (bool isBlaklisted, string memory err) {
        if (isZAccountIdBlacklisted[id]) {
            err = _formatBlackListError(err, ERR_BLACKLIST_ZACCOUNT_ID);
        }
        if (isMasterEoaBlacklisted[_masterEOA]) {
            err = _formatBlackListError(err, ERR_BLACKLIST_MASTER_EOA);
        }
        if (isPubRootSpendingKeyBlacklisted[pubRootSpendingKey]) {
            err = _formatBlackListError(
                err,
                ERR_BLACKLIST_PUB_ROOT_SPENDING_KEY
            );
        }

        return (isBlaklisted = bytes(err).length > 0 ? true : false, err);
    }

    function _formatBlackListError(
        string memory currentErrMsg,
        string memory errToBeAdded
    ) private pure returns (string memory newErrMsg) {
        return
            string(
                abi.encodePacked(
                    bytes(currentErrMsg).length > 0
                        ? string(abi.encodePacked(currentErrMsg, ","))
                        : "",
                    errToBeAdded
                )
            );
    }

    /// @dev Concatenate the strings together and returns the result
    function formatBlackListError(
        string memory content,
        string memory contentToBeAdded,
        string memory separator
    ) internal pure returns (string memory newErrMsg) {
        return
            string(
                abi.encodePacked(
                    bytes(content).length > 0
                        ? string(abi.encodePacked(content, separator))
                        : "",
                    contentToBeAdded
                )
            );
    }
}
