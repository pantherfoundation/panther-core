// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./interfaces/IOnboardingController.sol";
import "./interfaces/IPantherPoolV1.sol";
import "./pantherForest/interfaces/ITreeRootUpdater.sol";

import "../../common/crypto/BabyJubJub.sol";
import { FIELD_SIZE } from "../../common/crypto/SnarkConstants.sol";

import "./zAccountsRegistry/BlacklistedZAccountIdsTree.sol";
import "./zAccountsRegistry/ZAccountsRegeistrationSignatureVerifier.sol";
import { ZACCOUNT_STATUS } from "./zAccountsRegistry/Constants.sol";

import "../../common/ImmutableOwnable.sol";
import "../../common/Types.sol";
import "../../common/UtilsLib.sol";
import { ZACCOUNT_BLACKLIST_STATIC_LEAF_INDEX } from "./pantherForest/Constants.sol";

/**
 * @title ZAccountsRegistry
 * @author Pantherprotocol Contributors
 * @notice Registry and whitelist of zAccounts allowed to interact with MASP.
 * @dev The contract enables zAccount creation, activation, and blacklisting
 * within the protocol. Upon creation, user details are stored, and a unique
 * zAccount ID is generated.
 * Activation requires users to undergo a zero-knowledge proof process, with
 * verification by the Panther Pool resulting in the addition of the zAccount
 * UTXO commitment to the Merkle tree.
 * The DAO has authority to blacklist or unblacklist zAccounts, controlling
 * their protocol access. Blacklisted accounts are barred from engaging with
 * the protocol.
 * Additionally, the contract allocates ZKPs from a dedicated pool for
 * integration as zZKPs within zAccount UTXOs.
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

    uint256 private constant ZACCOUNT_ID_COUNTER_JUMP = 2;

    IPantherPoolV1 public immutable PANTHER_POOL;
    ITreeRootUpdater public immutable PANTHER_STATIC_TREE;
    IOnboardingController public immutable ONBOARDING_CONTROLLER;

    struct ZAccount {
        uint184 _unused; // reserved
        uint32 creationBlock; // timestamp of creation (registration)
        uint24 id; // the ZAccount id, starts from 0
        uint8 version; // ZAccount version
        ZACCOUNT_STATUS status;
        bytes32 pubRootSpendingKey;
        bytes32 pubReadingKey;
    }

    uint256 public zAccountIdTracker;

    mapping(bytes32 => uint256) public zoneZAccountNullifiers;
    mapping(bytes32 => uint256) public pubKeyZAccountNullifiers;
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

    function isZAccountWhitelisted(
        address _masterEOA
    ) external view returns (bool isWhitelisted) {
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

        uint24 zAccountId = uint24(_getNextZAccountId());

        ZAccount memory _zAccount = ZAccount({
            _unused: uint184(0),
            creationBlock: UtilsLib.safe32(block.number),
            id: zAccountId,
            version: uint8(ZACCOUNT_VERSION),
            status: ZACCOUNT_STATUS.REGISTERED,
            pubRootSpendingKey: pubRootSpendingKeyPacked,
            pubReadingKey: pubReadingKeyPacked
        });

        masterEOAs[zAccountId] = masterEoa;
        zAccounts[masterEoa] = _zAccount;

        emit ZAccountRegistered(masterEoa, _zAccount);
    }

    /// @notice Creates zAccount utxo
    /// @dev It can be executed only after registring the zAccount. It throws
    /// if the zAccount has not been registered or it's registered but it has been
    /// blacklisted.
    /// @param inputs The public input parameters to be passed to verifier.
    /// @param inputs[0]  - extraInputsHash
    /// @param inputs[1]  - zkpAmount
    /// @param inputs[2]  - zkpChange
    /// @param inputs[3]  - zAccountId
    /// @param inputs[4]  - zAccountPrpAmount
    /// @param inputs[5]  - zAccountCreateTime
    /// @param inputs[6]  - zAccountRootSpendPubKeyX
    /// @param inputs[7]  - zAccountRootSpendPubKeyY
    /// @param inputs[8]  - zAccountReadPubKeyX
    /// @param inputs[9]  - zAccountReadPubKeyY
    /// @param inputs[10] - zAccountNullifierPubKeyX
    /// @param inputs[11] - zAccountNullifierPubKeyY
    /// @param inputs[12] - zAccountMasterEOA
    /// @param inputs[13] - zAccountNullifierZone
    /// @param inputs[14] - zAccountCommitment
    /// @param inputs[15] - kycSignedMessageHash
    /// @param inputs[16] - forestMerkleRoot
    /// @param inputs[17] - saltHash
    /// @param inputs[18] - magicalConstraint
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// @param cachedForestRootIndex forest merkle root index. 0 means the most updated root.
    function activateZAccount(
        uint256[] calldata inputs,
        bytes memory privateMessages,
        SnarkProof calldata proof,
        uint256 cachedForestRootIndex
    ) external returns (uint256 utxoBusQueuePos) {
        {
            require(inputs[2] == 0, ERR_NON_ZERO_ZKP_CHANGE);

            uint256 extraInputsHash = inputs[0];
            bytes memory extraInp = abi.encodePacked(
                privateMessages,
                cachedForestRootIndex
            );
            require(
                extraInputsHash == uint256(keccak256(extraInp)) % FIELD_SIZE,
                ERR_INVALID_EXTRA_INPUT_HASH
            );
        }
        {
            uint256 zAccountPrpAmount = inputs[4];
            // No PRP rewards provided on zAccount activation
            require(zAccountPrpAmount == 0, ERR_UNEXPECTED_PRP_AMOUNT);
        }

        uint24 zAccountId = UtilsLib.safe24(inputs[3]);
        address zAccountMasterEOA = address(uint160(inputs[12]));

        require(
            masterEOAs[zAccountId] == zAccountMasterEOA,
            ERR_UNKNOWN_ZACCOUNT
        );

        // TODO: both `zAccountRootSpendPubKey` and `zAccountReadPubKeyX` should be checked
        // against the value that has been stored on registration
        {
            bytes32 zAccountRootSpendPubKey = BabyJubJub.pointPack(
                G1Point({ x: inputs[6], y: inputs[7] })
            );
            require(
                zAccounts[zAccountMasterEOA].pubRootSpendingKey ==
                    zAccountRootSpendPubKey,
                ERR_MISMATCH_PUB_SPEND_KEY
            );
            (bool isBlacklisted, string memory errMsg) = _isBlacklisted(
                zAccountId,
                zAccountMasterEOA,
                zAccountRootSpendPubKey
            );
            require(!isBlacklisted, errMsg);
        }

        {
            uint256 zAccountReadPubKeyX = inputs[8];
            uint256 zAccountReadPubKeyY = inputs[9];
            bytes32 zAccountReadPubKey = BabyJubJub.pointPack(
                G1Point({ x: zAccountReadPubKeyX, y: zAccountReadPubKeyY })
            );

            require(
                zAccountReadPubKeyX != 0 && zAccountReadPubKeyY != 0,
                ERR_UNEXPECTED_ZACCOUNT_READ_PUB_KEY
            );
            require(
                zAccounts[zAccountMasterEOA].pubReadingKey ==
                    zAccountReadPubKey,
                ERR_MISMATCH_PUB_READ_KEY
            );
        }

        {
            bytes32 pubKeyNullifier = BabyJubJub.pointPack(
                G1Point({ x: inputs[10], y: inputs[11] })
            );
            require(
                pubKeyZAccountNullifiers[pubKeyNullifier] == 0,
                ERR_DUPLICATED_NULLIFIER
            );

            pubKeyZAccountNullifiers[pubKeyNullifier] = block.number;
        }

        {
            // Prevent double-activation for the same zone and network
            bytes32 zoneNullifier = bytes32(inputs[13]);
            require(
                zoneZAccountNullifiers[zoneNullifier] == 0,
                ERR_DUPLICATED_NULLIFIER
            );

            zoneZAccountNullifiers[zoneNullifier] = block.number;
        }

        ZACCOUNT_STATUS userPrevStatus = zAccounts[zAccountMasterEOA].status;

        // if the status is registered, then change it to activate.
        // If status is already activated, it means  Zaccount is activated at least in 1 zone.
        if (userPrevStatus == ZACCOUNT_STATUS.REGISTERED) {
            zAccounts[zAccountMasterEOA].status = ZACCOUNT_STATUS.ACTIVATED;
        }

        {
            uint256 _zkpRewards = _notifyOnboardingController(
                zAccountMasterEOA,
                uint8(userPrevStatus),
                uint8(ZACCOUNT_STATUS.ACTIVATED),
                abi.encodePacked(inputs[17])
            );
            uint256 zkpAmount = inputs[1];
            require(_zkpRewards == zkpAmount, ERR_UNEXPECTED_ZKP_AMOUNT);
        }

        utxoBusQueuePos = _createZAccountUTXO(
            inputs,
            proof,
            privateMessages,
            cachedForestRootIndex
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

        // Trusted contract - no reentrancy guard needed
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
        bytes memory privateMessages,
        uint256 cachedForestRootIndex
    ) private returns (uint256 utxoBusQueuePos) {
        utxoBusQueuePos = 0;
        // Pool is supposed to revert in case of any error
        try
            // Trusted contract - no reentrancy guard needed
            PANTHER_POOL.createZAccountUtxo(
                inputs,
                proof,
                address(ONBOARDING_CONTROLLER),
                privateMessages,
                cachedForestRootIndex
            )
        returns (uint256 result) {
            utxoBusQueuePos = result;
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
        // Trusted contract - no reentrancy guard needed
        _zkpRewards = ONBOARDING_CONTROLLER.grantRewards(
            _user,
            _prevStatus,
            _newStatus,
            _data
        );
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

    function tempFixNullifiers(
        uint256[] calldata blockNums,
        uint256[] calldata zAccountNullifiers,
        uint256[] calldata zAccountIds
    ) external onlyOwner {
        require(
            blockNums.length == zAccountNullifiers.length,
            "invalid length"
        );
        for (uint256 i = 0; i < blockNums.length; i++) {
            zoneZAccountNullifiers[bytes32(zAccountNullifiers[i])] = blockNums[
                i
            ];

            emit ZAccountActivated(UtilsLib.safe24(zAccountIds[i]));
        }
    }
}
