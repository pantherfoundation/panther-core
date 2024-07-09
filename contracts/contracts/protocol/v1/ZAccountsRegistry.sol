// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./interfaces/IOnboardingController.sol";
import "./interfaces/IPantherPoolV1.sol";
import "./interfaces/IPrpVoucherGrantor.sol";
import "./pantherTrees/interfaces/ITreeRootUpdater.sol";
import "./pantherPool/publicSignals/ZAccountActivationPublicSignals.sol";

import "../../common/crypto/BabyJubJub.sol";
import { FIELD_SIZE } from "../../common/crypto/SnarkConstants.sol";

import "./zAccountsRegistry/BlacklistedZAccountIdsTree.sol";
import "./zAccountsRegistry/ZAccountsRegeistrationSignatureVerifier.sol";
import { ZACCOUNT_STATUS } from "./zAccountsRegistry/Constants.sol";

import { TT_ZACCOUNT_ACTIVATION, TT_ZACCOUNT_REACTIVATION } from "./pantherPool/Types.sol";

import "../../common/ImmutableOwnable.sol";
import "../../common/Types.sol";
import "../../common/UtilsLib.sol";
import { GT_ONBOARDING } from "../../common/Constants.sol";
import { ZACCOUNT_BLACKLIST_STATIC_LEAF_INDEX } from "./pantherTrees/Constants.sol";

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
    using UtilsLib for uint256;

    // The contract is supposed to run behind a proxy DELEGATECALLing it.
    // On upgrades, adjust `__gap` to match changes of the storage layout.
    // slither-disable-next-line shadowing-state unused-state
    uint256[50] private __gap;

    uint256 private constant ZACCOUNT_ID_COUNTER_JUMP = 2;

    IPantherPoolV1 public immutable PANTHER_POOL;
    ITreeRootUpdater public immutable PANTHER_STATIC_TREE;
    IPrpVoucherGrantor public immutable PRP_VOUCHER_GRANTOR;

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
    // TODO:to be deleted
    // left for storage compatibility of the "testnet" version, must be deleted in the prod version
    uint256 private _zAccountStatusGap;
    mapping(address => bool) public isMasterEoaBlacklisted;
    mapping(bytes32 => bool) public isPubRootSpendingKeyBlacklisted;
    mapping(uint24 => bool) public isZAccountIdBlacklisted;

    // Mapping from `MasterEoa` to ZAccount (i.e. params of an ZAccount)
    mapping(address => ZAccount) public zAccounts;

    // Mapping from zAccount Id to Master Eoa
    mapping(uint24 => address) public masterEOAs;

    mapping(bytes32 => uint256) public pubKeyZAccountNullifiers;

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
        address prpVoucherGrantor
    )
        ImmutableOwnable(_owner)
        ZAccountsRegeistrationSignatureVerifier(_zAccountVersion)
    {
        require(
            pantherPool != address(0) &&
                pantherStaticTree != address(0) &&
                prpVoucherGrantor != address(0),
            ERR_INIT_CONTRACT
        );

        PANTHER_POOL = IPantherPoolV1(pantherPool);
        PANTHER_STATIC_TREE = ITreeRootUpdater(pantherStaticTree);
        PRP_VOUCHER_GRANTOR = IPrpVoucherGrantor(prpVoucherGrantor);
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
        bytes memory privateMessages
    ) external returns (uint256 utxoBusQueuePos) {
        {
            uint256 extraInputsHash = inputs[
                ZACCOUNT_ACTIVATION_EXTRA_INPUT_HASH_IND
            ];
            bytes memory extraInp = abi.encodePacked(
                transactionOptions,
                paymasterCompensation,
                privateMessages
            );
            require(
                extraInputsHash == uint256(keccak256(extraInp)) % FIELD_SIZE,
                ERR_INVALID_EXTRA_INPUT_HASH
            );
        }

        uint24 zAccountId = inputs[ZACCOUNT_ACTIVATION_ZACCOUNT_ID_IND]
            .safe24();

        address zAccountMasterEOA = inputs[ZACCOUNT_ACTIVATION_MASTER_EOA_IND]
            .safeAddress();

        require(
            masterEOAs[zAccountId] == zAccountMasterEOA,
            ERR_UNKNOWN_ZACCOUNT
        );

        ZAccount memory _zAccount = zAccounts[zAccountMasterEOA];

        {
            bytes32 pubRootSpendingKey = BabyJubJub.pointPack(
                G1Point({
                    x: inputs[ZACCOUNT_ACTIVATION_ROOT_SPEND_PUB_KEY_X_IND],
                    y: inputs[ZACCOUNT_ACTIVATION_ROOT_SPEND_PUB_KEY_Y_IND]
                })
            );
            require(
                _zAccount.pubRootSpendingKey == pubRootSpendingKey,
                ERR_MISMATCH_PUB_SPEND_KEY
            );
            (bool isBlacklisted, string memory errMsg) = _isBlacklisted(
                zAccountId,
                zAccountMasterEOA,
                pubRootSpendingKey
            );
            require(!isBlacklisted, errMsg);
        }

        {
            bytes32 pubReadingKey = BabyJubJub.pointPack(
                G1Point({
                    x: inputs[ZACCOUNT_ACTIVATION_ROOT_READ_PUB_KEY_X_IND],
                    y: inputs[ZACCOUNT_ACTIVATION_ROOT_READ_PUB_KEY_Y_IND]
                })
            );

            require(
                _zAccount.pubReadingKey == pubReadingKey,
                ERR_MISMATCH_PUB_READ_KEY
            );
        }

        {
            bytes32 pubKeyNullifier = BabyJubJub.pointPack(
                G1Point({
                    x: inputs[
                        ZACCOUNT_ACTIVATION_ZACCOUNT_NULLIFIER_PUB_KEY_X_IND
                    ],
                    y: inputs[
                        ZACCOUNT_ACTIVATION_ZACCOUNT_NULLIFIER_PUB_KEY_Y_IND
                    ]
                })
            );
            require(
                pubKeyZAccountNullifiers[pubKeyNullifier] == 0,
                ERR_DUPLICATED_NULLIFIER
            );

            pubKeyZAccountNullifiers[pubKeyNullifier] = block.number;
        }

        {
            // Prevent double-activation for the same zone and network
            bytes32 zoneNullifier = bytes32(
                inputs[ZACCOUNT_ACTIVATION_NULLIFIER_ZONE_IND]
            );
            require(
                zoneZAccountNullifiers[zoneNullifier] == 0,
                ERR_DUPLICATED_NULLIFIER
            );

            zoneZAccountNullifiers[zoneNullifier] = block.number;
        }

        ZACCOUNT_STATUS userPrevStatus = _zAccount.status;

        uint16 transactionType;

        // if the status is registered, then change it to activate.
        // If status is already activated, it means  Zaccount is activated at least in 1 zone.
        if (userPrevStatus == ZACCOUNT_STATUS.REGISTERED) {
            zAccounts[zAccountMasterEOA].status = ZACCOUNT_STATUS.ACTIVATED;

            bytes32 secretHash = bytes32(
                inputs[ZACCOUNT_ACTIVATION_SALT_HASH_IND]
            );
            _grantPrpRewardsToUser(secretHash);
            transactionType = TT_ZACCOUNT_ACTIVATION;
        } else {
            transactionType = TT_ZACCOUNT_REACTIVATION;
        }

        utxoBusQueuePos = _createZAccountUTXO(
            inputs,
            proof,
            transactionOptions,
            transactionType,
            paymasterCompensation,
            privateMessages
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
        uint32 transactionOptions,
        uint16 transactionType,
        uint96 paymasterCompensation,
        bytes memory privateMessages
    ) private returns (uint256 utxoBusQueuePos) {
        utxoBusQueuePos = 0;
        // Pool is supposed to revert in case of any error
        try
            // Trusted contract - no reentrancy guard needed
            PANTHER_POOL.createZAccountUtxo(
                inputs,
                proof,
                transactionOptions,
                transactionType,
                paymasterCompensation,
                privateMessages
            )
        returns (uint256 result) {
            utxoBusQueuePos = result;
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    function _grantPrpRewardsToUser(bytes32 secretHash) private {
        try
            IPrpVoucherGrantor(PRP_VOUCHER_GRANTOR).generateRewards(
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
