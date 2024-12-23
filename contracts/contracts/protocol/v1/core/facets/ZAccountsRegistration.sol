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

/**
 * @title ZAccountsRegistration
 * @notice This contract manages the registration and activation of ZAccounts, which are secure accounts
 * associated with public keys for private transactions. It includes functionalities for
 * blacklisting master EOAs and public root spending keys, and provides mechanisms for
 * ZAccount activation through UTXOs.
 */
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

    uint256 private constant ZACCOUNT_ID_COUNTER_JUMP = 4;

    address internal immutable SELF;
    address internal immutable PANTHER_TREES;

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
    event ZAccountRenewed(uint24 id);
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

    /**
     * @notice Check if a ZAccount is whitelisted.
     * @param _masterEOA Address of the master EOA.
     * @return isWhitelisted True if the ZAccount is whitelisted, false otherwise.
     * @dev This function checks if a ZAccount exists and is not blacklisted.
     */
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

    /**
     * @notice Registers a new ZAccount.
     * @param _pubRootSpendingKey The public root spending key.
     * @param _pubReadingKey The public reading key.
     * @param v The recovery byte of the signature.
     * @param r The r value of the signature.
     * @param s The s value of the signature.
     */
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

        // Note: Registration requires KYC, ensuring that users are verified and reducing the risk of scams.
        // Therefore, using uint24 is sufficient, as the number of genuine users is expected to remain manageable.
        uint24 zAccountId = _getNextZAccountId().safe24();

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

    /**
     * @notice Creates a ZAccount UTXO to activate the zAccount.
     * @param inputs The public input parameters to be passed to verifier.
     * (see `ZAccountActivationPublicSignals.sol`).
     * @param proof The zero knowledge proof
     * @param transactionOptions A 17-bit number where the 8 LSB defines the cachedForestRootIndex,
     * the 1 MSB enables/disables the taxi tree, and other bits are reserved.
     * @param paymasterCompensation The compensation for the paymaster.
     * @param privateMessages The private messages.
     * (see `TransactionNoteEmitter.sol`).
     * @return utxoBusQueuePos The position in the UTXO bus queue.
     * @dev It can be executed only after registering the ZAccount. It throws
     * if the ZAccount has not been registered or it's registered but it has been
     * blacklisted.
     */
    function activateZAccount(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external returns (uint256 utxoBusQueuePos) {
        (
            address zAccountMasterEOA,
            uint24 zAccountId,
            ZACCOUNT_STATUS zAccountStatus
        ) = _verifyZAccount(inputs);

        uint16 transactionType = _activateZAccountStatusAndReturnTxType(
            zAccountMasterEOA,
            zAccountStatus
        );

        {
            if (transactionType == TT_ZACCOUNT_ACTIVATION) {
                bytes32 secretHash = bytes32(
                    inputs[ZACCOUNT_ACTIVATION_SALT_HASH_IND]
                );
                _grantPrpRewardsToUser(secretHash);
            }
        }

        utxoBusQueuePos = _processActivation(
            transactionType,
            inputs,
            proof,
            transactionOptions,
            paymasterCompensation,
            privateMessages
        );

        emit ZAccountActivated(zAccountId);
    }

    /**
     * @notice Creates a ZAccount UTXO to renew the zAccount.
     * @param inputs The public input parameters to be passed to verifier.
     * (see `ZAccountActivationPublicSignals.sol`).
     * @param proof The zero knowledge proof
     * @param transactionOptions A 17-bit number where the 8 LSB defines the cachedForestRootIndex,
     * the 1 MSB enables/disables the taxi tree, and other bits are reserved.
     * @param paymasterCompensation The compensation for the paymaster.
     * @param privateMessages The private messages.
     * (see `TransactionNoteEmitter.sol`).
     * @return utxoBusQueuePos The position in the UTXO bus queue.
     * @dev It can be executed only after activating the ZAccount. It throws
     * if the ZAccount has not been activated so far or it has been
     * blacklisted.
     */
    function renewZAccount(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external returns (uint256 utxoBusQueuePos) {
        (, uint24 zAccountId, ZACCOUNT_STATUS zAccountStatus) = _verifyZAccount(
            inputs
        );
        require(zAccountStatus == ZACCOUNT_STATUS.ACTIVATED, ERR_NOT_ACTIVATED);

        utxoBusQueuePos = _processActivation(
            TT_ZACCOUNT_RENEWAL,
            inputs,
            proof,
            transactionOptions,
            paymasterCompensation,
            privateMessages
        );

        emit ZAccountRenewed(zAccountId);
    }

    // /* ========== ONLY FOR OWNER FUNCTIONS ========== */

    /**
     * @notice Updates the blacklist status for multiple master EOAs.
     * @param masterEoas The addresses of the master EOAs to update.
     * @param isBlackListed The corresponding blacklist status for each master EOA.
     * @dev Only callable by the contract owner.
     */
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

    /**
     * @notice Updates the blacklist status for multiple public root spending keys.
     * @param packedPubRootSpendingKeys The public root spending keys to update.
     * @param isBlackListed The corresponding blacklist status for each key.
     * @dev Only callable by the contract owner.
     */
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

    /**
     * @notice Updates the blacklist status for a specific ZAccount ID.
     * @param zAccountId The ID of the ZAccount to update.
     * @param leaf The leaf to use in the blacklist update.
     * @param proofSiblings The proof siblings for the blacklist operation.
     * @param isBlacklisted The new blacklist status for the ZAccount ID.
     * @dev Only callable by the contract owner.
     */
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

    /**
     * @notice Gets the next ZAccount ID.
     * @dev This function increments the zAccountIdTracker and ensures it
     * does not exceed the maximum limit of 253.
     * @return curId The current ZAccount ID before incrementing.
     */
    function _getNextZAccountId() internal returns (uint256 curId) {
        curId = zAccountIdTracker;
        zAccountIdTracker = curId & 0xFF < 252
            ? curId + 1
            : curId + ZACCOUNT_ID_COUNTER_JUMP;
    }

    /**
     * @notice Validates extra inputs
     * @dev Checks the provided inputs against their expected hash to ensure data integrity.
     * @param extraInputsHash The hash of the extra inputs to validate.
     * @param transactionOptions Options for the transaction.
     * @param paymasterCompensation The compensation for the paymaster.
     * @param privateMessages Any private messages related to the transaction.
     */
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

    /**
     * @notice Checks that required public inputs are non-zero.
     * @dev Validates specific inputs to prevent zero values which could cause errors.
     * @param inputs An array of public input values to validate.
     */
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

    /**
     * @notice Activates the ZAccount status and returns the transaction type.
     * @dev Updates the ZAccount status based on the previous status and emits an event.
     * @param zAccountMasterEOA EOA address of the zAccount.
     * @param prevStatus The previous status of the ZAccount.
     * @return transactionType The type of transaction after activation.
     */
    function _activateZAccountStatusAndReturnTxType(
        address zAccountMasterEOA,
        ZACCOUNT_STATUS prevStatus
    ) private returns (uint16 transactionType) {
        // if the status is registered, then change it to activate.
        // If status is already activated, it means  Zaccount is activated at least in 1 zone.
        if (prevStatus == ZACCOUNT_STATUS.REGISTERED) {
            zAccounts[zAccountMasterEOA].status = ZACCOUNT_STATUS.ACTIVATED;

            transactionType = TT_ZACCOUNT_ACTIVATION;
        } else {
            transactionType = TT_ZACCOUNT_REACTIVATION;
        }
    }

    /**
     * @notice Verifies a ZAccount based on the provided inputs.
     * @dev Checks various conditions including blacklisting and key validation
     * before activating the ZAccount.
     * @param inputs An array of inputs required for verification and activation.
     * @return zAccountMasterEOA EOA address of the zAccount.
     * @return zAccountId Id of the zAccount.
     * @return zAccountStatus the current status of zAccount, can be registered
     * or activated
     */
    function _verifyZAccount(
        uint256[] calldata inputs
    )
        private
        view
        returns (
            address zAccountMasterEOA,
            uint24 zAccountId,
            ZACCOUNT_STATUS zAccountStatus
        )
    {
        zAccountMasterEOA = inputs[ZACCOUNT_ACTIVATION_MASTER_EOA_IND]
            .safeAddress();

        zAccountId = inputs[ZACCOUNT_ACTIVATION_ZACCOUNT_ID_IND].safe24();

        require(
            masterEOAs[zAccountId] == zAccountMasterEOA,
            ERR_UNKNOWN_ZACCOUNT
        );

        ZAccount memory _zAccount = zAccounts[zAccountMasterEOA];
        bytes32 rootSpendingKey = _zAccount.pubRootSpendingKey;
        bytes32 readingKey = _zAccount.pubReadingKey;
        zAccountStatus = _zAccount.status;

        (bool isBlacklisted, string memory errMsg) = _isBlacklisted(
            zAccountId,
            zAccountMasterEOA,
            rootSpendingKey
        );
        require(!isBlacklisted, errMsg);

        _validateSpendingAndReadingKeys(inputs, rootSpendingKey, readingKey);
    }

    /**
     * @notice Validates the spending and reading keys against provided inputs.
     * @dev Ensures that the keys match the expected values to prevent unauthorized access.
     * @param inputs An array of input values that include the keys.
     * @param zAccountPubRootSpendingKey The expected public root spending key.
     * @param zAccountReadingKey The expected reading key.
     */
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

    /**
     * @notice Inserts utxos into the panther trees and emit tx note event
     * @param transactionType the tx type, can be activation, reactivation, or,
     * renewal
     * @param inputs The public input parameters to be passed to verifier.
     * (see `ZAccountActivationPublicSignals.sol`).
     * @param proof The zero knowledge proof
     * @param transactionOptions A 17-bit number where the 8 LSB defines the cachedForestRootIndex,
     * the 1 MSB enables/disables the taxi tree, and other bits are reserved.
     * @param paymasterCompensation The compensation for the paymaster.
     * @param privateMessages The private messages.
     * (see `TransactionNoteEmitter.sol`).
     * @return utxoBusQueuePos The position in the UTXO bus queue.
     */
    function _processActivation(
        uint16 transactionType,
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) private returns (uint256 utxoBusQueuePos) {
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

        _validateAndSpendNullifiers(inputs);

        _sanitizePrivateMessage(privateMessages, transactionType);

        {
            uint160 circuitId = circuitIds[transactionType];
            verifyOrRevert(circuitId, inputs, proof);
        }

        uint96 miningReward = accountFeesAndReturnMiningReward(
            feeMasterDebt,
            inputs,
            paymasterCompensation,
            transactionType
        );

        utxoBusQueuePos = _insertUtxosAndEmitZAccountActivationNote(
            transactionType,
            inputs,
            transactionOptions,
            miningReward,
            privateMessages
        );
    }

    /**
     * @notice Validates and spends nullifiers for ZAccount activation.
     * @dev Checks the nullifiers to prevent double activation in the same zone and network.
     * @param inputs An array of inputs that include nullifier keys.
     */
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

    /**
     * @notice Inserts utxos into the panther trees and emit tx note event
     * @param transactionType the tx type, can be activation, reactivation, or,
     * renewal
     * @param inputs The public input parameters to be passed to verifier.
     * (see `ZAccountActivationPublicSignals.sol`).
     * @param transactionOptions A 17-bit number where the 8 LSB defines the cachedForestRootIndex,
     * the 1 MSB enables/disables the taxi tree, and other bits are reserved.
     * @param privateMessages The private messages.
     * (see `TransactionNoteEmitter.sol`).
     * @return utxoBusQueuePos The position in the UTXO bus queue.
     */
    function _insertUtxosAndEmitZAccountActivationNote(
        uint16 transactionType,
        uint256[] calldata inputs,
        uint32 transactionOptions,
        uint96 miningReward,
        bytes calldata privateMessages
    ) private returns (uint256 utxoBusQueuePos) {
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

    /**
     * @notice Grants rewards to a user based on a secret hash.
     * @dev Attempts to generate rewards and catches any errors for handling.
     * @param secretHash The hash representing the user's secret for reward generation.
     */
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

    /**
     * @notice Checks if a ZAccount or related keys are blacklisted.
     * @dev Evaluates multiple conditions to determine if the ZAccount is blacklisted.
     * @param id The ID of the ZAccount.
     * @param _masterEOA The address of the master EOA to check.
     * @param pubRootSpendingKey The public root spending key to validate.
     * @return isBlacklisted Indicates if the ZAccount or keys are blacklisted.
     * @return err Any error messages related to the blacklist status.
     */
    function _isBlacklisted(
        uint24 id,
        address _masterEOA,
        bytes32 pubRootSpendingKey
    ) private view returns (bool isBlacklisted, string memory err) {
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

        return (isBlacklisted = bytes(err).length > 0 ? true : false, err);
    }

    /**
     * @notice Formats the blacklist error message.
     * @dev Concatenates the current error message with the new error to provide a comprehensive error report.
     * @param currentErrMsg The existing error message.
     * @param errToBeAdded The new error message to add.
     * @return newErrMsg The formatted error message containing both the current and new errors.
     */
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
