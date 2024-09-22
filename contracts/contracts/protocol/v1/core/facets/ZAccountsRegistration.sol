// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../storage/AppStorage.sol";
import "../storage/ZAccountsRegistrationStorageGap.sol";

import "../../diamond/utils/Ownable.sol";
import "../../verifier/Verifier.sol";

import "../interfaces/IPrpVoucherController.sol";
import "../interfaces/IBlacklistedZAccountIdRegistry.sol";

import "../errMsgs/ZAccountsRegistryErrMsgs.sol";

import "../../../../common/crypto/BabyJubJub.sol";
import { GT_ONBOARDING } from "../../../../common/Constants.sol";
import { ZACCOUNT_STATUS } from "./zAccountsRegistration/Constants.sol";

import "./zAccountsRegistration/ZAccountsRegeistrationSignatureVerifier.sol";
import "../utils/TransactionNoteEmitter.sol";
import "../utils/TransactionChargesHandler.sol";

import "../libraries/UtxosInserter.sol";
import "../libraries/NullifierSpender.sol";
import "../libraries/PublicInputGuard.sol";

// solhint-disable contract-name-camelcase
contract ZAccountsRegistration is
    AppStorage,
    ZAccountsRegistrationStorageGap,
    Ownable,
    Verifier,
    ZAccountsRegeistrationSignatureVerifier,
    TransactionNoteEmitter,
    TransactionChargesHandler
{
    using UtilsLib for uint256;
    using PublicInputGuard for uint256;
    using PublicInputGuard for address;
    using TransactionOptions for uint32;
    using UtxosInserter for address;
    using NullifierSpender for mapping(bytes32 => uint256);

    uint256 private constant ZACCOUNT_ID_COUNTER_JUMP = 3;

    address public immutable SELF;
    address public immutable PANTHER_TREES;

    struct ZAccount {
        uint184 _unused; // reserved
        uint32 creationBlock; // block num of creation (registration)
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
        uint8 _zAccountVersion,
        address self,
        address pantherTrees,
        address feeMaster,
        address zkpToken
    )
        ZAccountsRegeistrationSignatureVerifier(_zAccountVersion)
        TransactionChargesHandler(feeMaster, zkpToken)
    {
        require(pantherTrees != address(0), ERR_INIT_CONTRACT);

        SELF = self;
        PANTHER_TREES = pantherTrees;
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

    /* ========== EXTERNAL FUNCTIONS ========== */

    /// @dev Note comments to `function isAcceptablePubKey`
    function registerZAccount(
        G1Point memory _pubRootSpendingKey,
        G1Point memory _pubReadingKey,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // If pub keys belong to the subgroup is not checked to save gas costs
        BabyJubJub.requirePointInCurveExclIdentity(_pubRootSpendingKey);
        BabyJubJub.requirePointInCurveExclIdentity(_pubReadingKey);

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
            zAccounts[masterEoa].status == ZACCOUNT_STATUS.UNDEFINED,
            ERR_DUPLICATED_MASTER_EOA
        );

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
    /// @param inputs[1]  - addedAmountZkp
    /// @param inputs[2]  - chargedAmountZkp
    /// @param inputs[3]  - zAccountId
    /// @param inputs[4]  - zAccountCreateTime
    /// @param inputs[5]  - zAccountRootSpendPubKeyX
    /// @param inputs[6]  - zAccountRootSpendPubKeyY
    /// @param inputs[7]  - zAccountReadPubKeyX
    /// @param inputs[8]  - zAccountReadPubKeyY
    /// @param inputs[9] - zAccountNullifierPubKeyX
    /// @param inputs[10] - zAccountNullifierPubKeyY
    /// @param inputs[11] - zAccountMasterEOA
    /// @param inputs[12] - zAccountNullifierZone
    /// @param inputs[13] - zAccountCommitment
    /// @param inputs[14] - kycSignedMessageHash
    /// @param inputs[15] - staticTreeMerkleRoot
    /// @param inputs[16] - forestMerkleRoot
    /// @param inputs[17] - saltHash
    /// @param inputs[18] - magicalConstraint
    /// @param proof A proof associated with the zAccount and a secret.
    /// @param privateMessages the private message that contains zAccount utxo data.
    /// zAccount utxo data contains bytes1 msgType, bytes32 ephemeralKey and bytes64 cypherText
    /// @param transactionOptions A 17-bits number. The 8 LSB (bits at position 1 to
    /// position 8) defines the cachedForestRootIndex and the 1 MSB (bit at position 17) enables/disables
    /// the taxi tree. Other bits are reserved.
    function activateZAccount(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external returns (uint256 utxoBusQueuePos) {
        _validateExtraInputs(
            inputs[ZACCOUNT_ACTIVATION_EXTRA_INPUT_HASH_IND],
            transactionOptions,
            paymasterCompensation,
            privateMessages
        );

        _checkNonZeroPublicInputs(inputs);

        {
            uint256 creationTime = inputs[
                ZACCOUNT_ACTIVATION_UTXO_OUT_CREATE_TIME_IND
            ];
            creationTime.validateCreationTime(maxBlockTimeOffset);
        }

        _sanitizePrivateMessage(privateMessages, TT_ZACCOUNT_ACTIVATION);

        _validateAndSpendNullifiers(inputs);

        uint16 transactionType = _verifyAndActivateZAccount(inputs);

        {
            if (transactionType == TT_ZACCOUNT_ACTIVATION) {
                bytes32 secretHash = bytes32(
                    inputs[ZACCOUNT_ACTIVATION_SALT_HASH_IND]
                );
                _grantPrpRewardsToUser(secretHash);
            }
        }

        {
            uint160 circuitId = circuitIds[TT_ZACCOUNT_ACTIVATION];
            verifyOrRevert(circuitId, inputs, proof);
        }

        uint96 miningReward = accountFeesAndReturnMiningReward(
            feeMasterDebt,
            inputs,
            paymasterCompensation,
            transactionType
        );

        uint32 zAccountUtxoQueueId;
        uint8 zAccountUtxoIndexInQueue;

        (
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            utxoBusQueuePos
        ) = PANTHER_TREES.insertZAccountActivationUtxos(
            inputs,
            transactionOptions,
            miningReward
        );

        _emitZAccountActivationNote(
            inputs,
            zAccountUtxoQueueId,
            zAccountUtxoIndexInQueue,
            transactionType,
            privateMessages
        );
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

        if (isBlacklisted) {
            IBlacklistedZAccountIdRegistry(PANTHER_TREES)
                .addZAccountIdToBlacklist(zAccountId, leaf, proofSiblings);
        } else {
            IBlacklistedZAccountIdRegistry(PANTHER_TREES)
                .removeZAccountIdFromBlacklist(zAccountId, leaf, proofSiblings);
        }

        isZAccountIdBlacklisted[zAccountId] = isBlacklisted;

        emit BlacklistForZAccountIdUpdated(zAccountId, isBlacklisted);
    }

    // /* ========== PRIVATE FUNCTIONS ========== */

    function _getNextZAccountId() internal returns (uint256 curId) {
        curId = zAccountIdTracker;
        zAccountIdTracker = curId & 0xFF < 253
            ? curId + 1
            : curId + ZACCOUNT_ID_COUNTER_JUMP;
    }

    function _validateExtraInputs(
        uint256 extraInputsHash,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) private pure {
        bytes memory extraInp = abi.encodePacked(
            transactionOptions,
            paymasterCompensation,
            privateMessages
        );

        extraInputsHash.validateExtraInputHash(extraInp);
    }

    function _checkNonZeroPublicInputs(uint256[] calldata inputs) private pure {
        inputs[ZACCOUNT_ACTIVATION_SALT_HASH_IND].validateNonZero(
            "ERR_ZERO_SALT_HASH"
        );
        inputs[ZACCOUNT_ACTIVATION_MAGICAL_CONSTRAINT_IND].validateNonZero(
            "ERR_ZERO_MAGIC_CONSTR"
        );
        inputs[ZACCOUNT_ACTIVATION_NULLIFIER_ZONE_IND].validateNonZero(
            "ERR_ZERO_NULLIFIER"
        );

        inputs[ZACCOUNT_ACTIVATION_UTXO_OUT_COMMITMENT_IND].validateNonZero(
            "ERR_ZERO_ZACCOUNT_COMMIT"
        );
        inputs[ZACCOUNT_ACTIVATION_KYC_SIGNED_MESSAGE_HASH_IND].validateNonZero(
                "ERR_ZERO_KYC_MSG_HASH"
            );
    }

    function _verifyAndActivateZAccount(
        uint256[] calldata inputs
    ) private returns (uint16 transactionType) {
        address zAccountMasterEOA = inputs[ZACCOUNT_ACTIVATION_MASTER_EOA_IND]
            .safeAddress();

        uint24 zAccountId = inputs[ZACCOUNT_ACTIVATION_ZACCOUNT_ID_IND]
            .safe24();

        require(
            masterEOAs[zAccountId] == zAccountMasterEOA,
            ERR_UNKNOWN_ZACCOUNT
        );

        ZAccount memory _zAccount = zAccounts[zAccountMasterEOA];
        bytes32 rootSpendingKey = _zAccount.pubRootSpendingKey;
        bytes32 readingKey = _zAccount.pubReadingKey;
        ZACCOUNT_STATUS zAccountStatus = _zAccount.status;

        (bool isBlacklisted, string memory errMsg) = _isBlacklisted(
            zAccountId,
            zAccountMasterEOA,
            rootSpendingKey
        );
        require(!isBlacklisted, errMsg);

        _validateSpendingAndReadingKeys(inputs, rootSpendingKey, readingKey);

        transactionType = _activateZAccountStatusAndReturnTxType(
            zAccountStatus,
            zAccountMasterEOA,
            zAccountId
        );
    }

    function _validateSpendingAndReadingKeys(
        uint256[] calldata inputs,
        bytes32 zAccountPubRootSpendingKey,
        bytes32 zAccountReadingKey
    ) private pure {
        {
            bytes32 pubRootSpendingKey = BabyJubJub.pointPack(
                G1Point({
                    x: inputs[ZACCOUNT_ACTIVATION_ROOT_SPEND_PUB_KEY_X_IND],
                    y: inputs[ZACCOUNT_ACTIVATION_ROOT_SPEND_PUB_KEY_Y_IND]
                })
            );
            require(
                zAccountPubRootSpendingKey == pubRootSpendingKey,
                ERR_MISMATCH_PUB_SPEND_KEY
            );
        }

        {
            bytes32 pubReadingKey = BabyJubJub.pointPack(
                G1Point({
                    x: inputs[ZACCOUNT_ACTIVATION_ROOT_READ_PUB_KEY_X_IND],
                    y: inputs[ZACCOUNT_ACTIVATION_ROOT_READ_PUB_KEY_Y_IND]
                })
            );

            require(
                zAccountReadingKey == pubReadingKey,
                ERR_MISMATCH_PUB_READ_KEY
            );
        }
    }

    function _validateAndSpendNullifiers(uint256[] calldata inputs) private {
        bytes32 pubKeyNullifier = BabyJubJub.pointPack(
            G1Point({
                x: inputs[ZACCOUNT_ACTIVATION_ZACCOUNT_NULLIFIER_PUB_KEY_X_IND],
                y: inputs[ZACCOUNT_ACTIVATION_ZACCOUNT_NULLIFIER_PUB_KEY_Y_IND]
            })
        );

        // Prevent double-activation for the same zone and network
        uint256 zoneNullifier = inputs[ZACCOUNT_ACTIVATION_NULLIFIER_ZONE_IND];

        pubKeyZAccountNullifiers.validateAndSpendNullifier(
            uint256(pubKeyNullifier)
        );
        zoneZAccountNullifiers.validateAndSpendNullifier(zoneNullifier);
    }

    function _activateZAccountStatusAndReturnTxType(
        ZACCOUNT_STATUS prevStatus,
        address zAccountEoa,
        uint24 zAccountId
    ) private returns (uint16 transactionType) {
        // if the status is registered, then change it to activate.
        // If status is already activated, it means  Zaccount is activated at least in 1 zone.
        if (prevStatus == ZACCOUNT_STATUS.REGISTERED) {
            zAccounts[zAccountEoa].status = ZACCOUNT_STATUS.ACTIVATED;

            transactionType = TT_ZACCOUNT_ACTIVATION;
        } else {
            transactionType = TT_ZACCOUNT_REACTIVATION;
        }

        emit ZAccountActivated(zAccountId);
    }

    function _grantPrpRewardsToUser(bytes32 secretHash) private {
        try
            IPrpVoucherController(SELF).generateRewards(
                secretHash,
                0, // amount defined for `GT_ONBOARDING` type will be used
                GT_ONBOARDING
            )
        // solhint-disable-next-line no-empty-blocks
        {

        } catch Error(string memory reason) {
            revert(reason);
        }
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

    /// @dev Concatenate the strings together and returns the result
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
}
