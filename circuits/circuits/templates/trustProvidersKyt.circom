// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.1.9;

include "./trustProvidersMerkleTreeLeafIDAndRuleInclusionProver.circom";
include "./trustProvidersNoteInclusionProver.circom";
include "./utils.circom";

include "../../node_modules/circomlib/circuits/babyjub.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

template TrustProvidersInternalKyt(IsTestNet) {
    signal input                        kytRandom;
    signal input {sub_order_bj_p}       kytPubKey[2];
    signal input {uint32}               kytPubKeyExpiryTime;
    signal input {uint32}               zZoneKytExpiryTime;
    signal input {uint32}               createTime;
    signal input {uint160}              kytMasterEOA;

    signal input {binary}               enabled;

    signal input                        kytSignedMessagePackageType;
    signal input                        kytSignedMessageTimestamp;
    signal input                        kytSignedMessageSessionId;
    signal input {uint160}              kytSignedMessageSigner;
    signal input {uint96}               kytSignedMessageChargedAmountZkp;
    signal input                        kytSignedDepositSignedMessageHash;
    signal input                        kytSignedWithdrawSignedMessageHash;
    signal input                        kytSignedMessageDataEscrowHash;
    signal input                        kytSignedMessageHash;
    signal input                        kytSignature[3];

    component kytSignedMessageHashInternal;

    if (IsTestNet) { // TestNet only
        // for testnet case require zero
        kytSignedMessageChargedAmountZkp === 0;

        // Signed Hash
        kytSignedMessageHashInternal = Poseidon(7);

        kytSignedMessageHashInternal.inputs[0] <== kytSignedMessagePackageType;
        kytSignedMessageHashInternal.inputs[1] <== kytSignedMessageTimestamp;
        kytSignedMessageHashInternal.inputs[2] <== kytSignedMessageSessionId;
        kytSignedMessageHashInternal.inputs[3] <== kytSignedMessageSigner;
        kytSignedMessageHashInternal.inputs[4] <== kytSignedDepositSignedMessageHash;
        kytSignedMessageHashInternal.inputs[5] <== kytSignedWithdrawSignedMessageHash;
        kytSignedMessageHashInternal.inputs[6] <== kytSignedMessageDataEscrowHash;

    } else { // Production
        // Modification (instead of `signer`)
        component kytInternalHash = Poseidon(4);
        kytInternalHash.inputs[0] <== kytSignedMessageSigner; // same as before
        kytInternalHash.inputs[1] <== kytSignedMessageChargedAmountZkp; // zkp amount
        kytInternalHash.inputs[2] <== kytRandom; // random that will be send to KYT
        kytInternalHash.inputs[3] <== kytSignedMessageSessionId;

        // Signed Hash
        kytSignedMessageHashInternal = Poseidon(6);
        kytSignedMessageHashInternal.inputs[0] <== kytSignedMessagePackageType;
        kytSignedMessageHashInternal.inputs[1] <== kytSignedMessageTimestamp;
        kytSignedMessageHashInternal.inputs[2] <== kytInternalHash.out;
        kytSignedMessageHashInternal.inputs[3] <== kytSignedDepositSignedMessageHash;
        kytSignedMessageHashInternal.inputs[4] <== kytSignedWithdrawSignedMessageHash;
        kytSignedMessageHashInternal.inputs[5] <== kytSignedMessageDataEscrowHash;
    }

    component kytSignatureVerifier = EdDSAPoseidonVerifier();
    kytSignatureVerifier.enabled <== enabled;
    kytSignatureVerifier.Ax <== kytPubKey[0];
    kytSignatureVerifier.Ay <== kytPubKey[1];
    kytSignatureVerifier.S <== kytSignature[0];
    kytSignatureVerifier.R8x <== kytSignature[1];
    kytSignatureVerifier.R8y <== kytSignature[2];

    kytSignatureVerifier.M <== kytSignedMessageHashInternal.out;

    // internal Master EOA check
    component kytMasterEOAIsEqual = ForceEqualIfEnabled();
    kytMasterEOAIsEqual.enabled <== enabled;
    kytMasterEOAIsEqual.in[0] <== kytSignedMessageSigner;
    kytMasterEOAIsEqual.in[1] <== kytMasterEOA;

    // internal kyt hash
    component kytSignedMessageHashIsEqual = ForceEqualIfEnabled();
    kytSignedMessageHashIsEqual.enabled <== enabled;
    kytSignedMessageHashIsEqual.in[0] <== kytSignedMessageHash;
    kytSignedMessageHashIsEqual.in[1] <== kytSignedMessageHashInternal.out;

    // internal package type
    component kytInternalPackageTypeIsEqual = ForceEqualIfEnabled();
    kytInternalPackageTypeIsEqual.enabled <== enabled;
    kytInternalPackageTypeIsEqual.in[0] <== kytSignedMessagePackageType;
    kytInternalPackageTypeIsEqual.in[1] <== 253;

    // check if signing key is still valid
    component isLessThanEq_InternalTime_kytEdDsaPubKeyExpiryTime = LessEqThanWhenEnabled(252);
    isLessThanEq_InternalTime_kytEdDsaPubKeyExpiryTime.enabled <== enabled;
    isLessThanEq_InternalTime_kytEdDsaPubKeyExpiryTime.in[0] <== kytSignedMessageTimestamp;
    isLessThanEq_InternalTime_kytEdDsaPubKeyExpiryTime.in[1] <== kytPubKeyExpiryTime;

    // check if kyt is still valid: tx create time <= kyt timestamp + zZone Delta time (for kyt)
    component isLessThanEq_createTime_I_Timestamp = LessEqThanWhenEnabled(252);
    isLessThanEq_createTime_I_Timestamp.enabled <== enabled;
    isLessThanEq_createTime_I_Timestamp.in[0] <== createTime;
    isLessThanEq_createTime_I_Timestamp.in[1] <== kytSignedMessageTimestamp + zZoneKytExpiryTime;
}

template TrustProvidersDepositWithdrawKyt(IsTestNet) {
    signal input                        kytRandom;
    signal input {uint160}              kytToken;
    signal input {uint96}               kytAmount;
    signal input {sub_order_bj_p}       kytPubKey[2];
    signal input {uint32}               kytPubKeyExpiryTime;
    signal input {uint32}               zZoneKytExpiryTime;
    signal input {uint32}               createTime;
    signal input {uint160}              kytMasterEOA;
    signal input {uint4}                kytMerkleTreeLeafIDsAndRulesOffset;
    signal input {uint240}              kytTrustProvidersMerkleTreeLeafIDsAndRulesList;
    signal input {uint16}               kytLeafId;

    signal input {binary}               enabled;

    signal input                        kytSignedMessagePackageType;
    signal input                        kytSignedMessageTimestamp;
    signal input                        kytSignedMessageSender;
    signal input                        kytSignedMessageReceiver;
    signal input {uint160}              kytSignedMessageToken;
    signal input                        kytSignedMessageSessionId;
    signal input {uint8}                kytSignedMessageRuleId;
    signal input {uint96}               kytSignedMessageAmount;
    signal input {uint96}               kytSignedMessageChargedAmountZkp;
    signal input {uint160}              kytSignedMessageSigner;
    signal input                        kytSignedMessageHash;
    signal input                        kytSignature[3];

    component kytSignedMessageHashInternal;

    if ( IsTestNet ) { // TestNet only
        // for testnet case require zero
        kytSignedMessageChargedAmountZkp === 0;

        // Signed hash
        kytSignedMessageHashInternal = Poseidon(9);

        kytSignedMessageHashInternal.inputs[0] <== kytSignedMessagePackageType;
        kytSignedMessageHashInternal.inputs[1] <== kytSignedMessageTimestamp;
        kytSignedMessageHashInternal.inputs[2] <== kytSignedMessageSender;
        kytSignedMessageHashInternal.inputs[3] <== kytSignedMessageReceiver;
        kytSignedMessageHashInternal.inputs[4] <== kytSignedMessageToken;
        kytSignedMessageHashInternal.inputs[5] <== kytSignedMessageSessionId;
        kytSignedMessageHashInternal.inputs[6] <== kytSignedMessageRuleId;
        kytSignedMessageHashInternal.inputs[7] <== kytSignedMessageAmount;
        kytSignedMessageHashInternal.inputs[8] <== kytSignedMessageSigner;
    } else { // Production
        // Modification (instead of `signer`)
        component kytInternalHash = Poseidon(5);
        kytInternalHash.inputs[0] <== kytSignedMessageSigner; // same as before
        kytInternalHash.inputs[1] <== kytSignedMessageChargedAmountZkp; // zkp amount
        kytInternalHash.inputs[2] <== kytRandom; // random that will be send to KYT
        kytInternalHash.inputs[3] <== kytSignedMessageSessionId;
        kytInternalHash.inputs[4] <== kytSignedMessageRuleId;

        kytSignedMessageHashInternal = Poseidon(7);

        kytSignedMessageHashInternal.inputs[0] <== kytSignedMessagePackageType;
        kytSignedMessageHashInternal.inputs[1] <== kytSignedMessageTimestamp;
        kytSignedMessageHashInternal.inputs[2] <== kytSignedMessageSender;
        kytSignedMessageHashInternal.inputs[3] <== kytSignedMessageReceiver;
        kytSignedMessageHashInternal.inputs[4] <== kytSignedMessageToken;
        kytSignedMessageHashInternal.inputs[5] <== kytSignedMessageAmount;
        kytSignedMessageHashInternal.inputs[6] <== kytInternalHash.out;
    }
    component kytSignatureVerifier = EdDSAPoseidonVerifier();
    kytSignatureVerifier.enabled <== enabled;
    kytSignatureVerifier.Ax <== kytPubKey[0];
    kytSignatureVerifier.Ay <== kytPubKey[1];
    kytSignatureVerifier.S <== kytSignature[0];
    kytSignatureVerifier.R8x <== kytSignature[1];
    kytSignatureVerifier.R8y <== kytSignature[2];

    kytSignatureVerifier.M <== kytSignedMessageHashInternal.out;

    // Master EOA check
    component kytMasterEOAIsEqual = ForceEqualIfEnabled();
    kytMasterEOAIsEqual.enabled <== enabled;
    kytMasterEOAIsEqual.in[0] <== kytSignedMessageSigner;
    kytMasterEOAIsEqual.in[1] <== kytMasterEOA;

    // kyt-hash
    component kytSignedMessageHashIsEqual = ForceEqualIfEnabled();
    kytSignedMessageHashIsEqual.enabled <== enabled;
    kytSignedMessageHashIsEqual.in[0] <== kytSignedMessageHash;
    kytSignedMessageHashIsEqual.in[1] <== kytSignedMessageHashInternal.out;

    // token
    component kytSignedMessageTokenIsEqual = ForceEqualIfEnabled();
    kytSignedMessageTokenIsEqual.enabled <== enabled;
    kytSignedMessageTokenIsEqual.in[0] <== kytToken;
    kytSignedMessageTokenIsEqual.in[1] <== kytSignedMessageToken;

    // amount
    component kytSignedMessageAmountIsEqual = ForceEqualIfEnabled();
    kytSignedMessageAmountIsEqual.enabled <== enabled;
    kytSignedMessageAmountIsEqual.in[0] <== kytAmount;
    kytSignedMessageAmountIsEqual.in[1] <== kytSignedMessageAmount;

    // check if kyt signed by not expired key: kyt timestamp <= kytPubKeyExpiryTime
    component isLessThanEq_DW_Time_kytEdDsaPubKeyExpiryTime = LessEqThanWhenEnabled(252);
    isLessThanEq_DW_Time_kytEdDsaPubKeyExpiryTime.enabled <== enabled;
    isLessThanEq_DW_Time_kytEdDsaPubKeyExpiryTime.in[0] <== kytSignedMessageTimestamp;
    isLessThanEq_DW_Time_kytEdDsaPubKeyExpiryTime.in[1] <== kytPubKeyExpiryTime;

    // check if kyt is still valid: tx create time <= kyt timestamp + zZone Delta time (for kyt)
    component isLessThanEq_createTime_DW_Timestamp = LessEqThanWhenEnabled(252);
    isLessThanEq_createTime_DW_Timestamp.enabled <== enabled;
    isLessThanEq_createTime_DW_Timestamp.in[0] <== createTime;
    isLessThanEq_createTime_DW_Timestamp.in[1] <== kytSignedMessageTimestamp + zZoneKytExpiryTime;

    // package type
    component kytSignedMessagePackageTypeIsEqual = ForceEqualIfEnabled();
    kytSignedMessagePackageTypeIsEqual.enabled <== enabled;
    kytSignedMessagePackageTypeIsEqual.in[0] <== kytSignedMessagePackageType;
    kytSignedMessagePackageTypeIsEqual.in[1] <== 2;

    // inclusion proof
    component kytLeafIdAndRuleInclusionProver = TrustProvidersMerkleTreeLeafIDAndRuleInclusionProver();
    kytLeafIdAndRuleInclusionProver.enabled <== enabled;
    kytLeafIdAndRuleInclusionProver.leafId <== kytLeafId;
    kytLeafIdAndRuleInclusionProver.rule <== kytSignedMessageRuleId;
    kytLeafIdAndRuleInclusionProver.leafIDsAndRulesList <== kytTrustProvidersMerkleTreeLeafIDsAndRulesList;
    kytLeafIdAndRuleInclusionProver.offset <== kytMerkleTreeLeafIDsAndRulesOffset;
}

template TrustProvidersKyt(isSwap, TrustProvidersMerkleTreeDepth, IsTestNet) {
    signal input                  kytRandom;
    signal input {uint168}        kytToken;
    signal input {uint96}         kytDepositAmount;
    signal input {uint96}         kytWithdrawAmount;
    signal input {uint160}        kytMasterEOA;
    signal input {binary}         kytSealing;

    // KYC-KYT
    // to switch-off:
    //      1) depositAmount = 0
    //      2) withdrawAmount = 0
    // Note: for swap case, kyt-hash = zero also can switch-off the KYT verification check
    // switch-off control is used for internal tx
    signal input {sub_order_bj_p} kytEdDsaPubKey[2];
    signal input {uint32}         kytEdDsaPubKeyExpiryTime;
    signal input {uint32}         createTime;
    signal input {uint32}         zZoneKytExpiryTime;
    signal input                  trustProvidersMerkleRoot;
    signal input                  kytPathElements[TrustProvidersMerkleTreeDepth];
    signal input {binary}         kytPathIndices[TrustProvidersMerkleTreeDepth];
    signal input {uint240}        kytTrustProvidersMerkleTreeLeafIDsAndRulesList;
    signal input {uint4}          kytMerkleTreeLeafIDsAndRulesOffset;

    // deposit case
    signal input            kytDepositSignedMessagePackageType;
    signal input            kytDepositSignedMessageTimestamp;
    signal input            kytDepositSignedMessageSender;
    signal input            kytDepositSignedMessageReceiver;
    signal input {uint160}  kytDepositSignedMessageToken;
    signal input            kytDepositSignedMessageSessionId;
    signal input {uint8}    kytDepositSignedMessageRuleId;
    signal input {uint96}   kytDepositSignedMessageAmount;
    signal input {uint96}   kytDepositSignedMessageChargedAmountZkp;
    signal input {uint160}  kytDepositSignedMessageSigner;
    signal input            kytDepositSignedMessageHash;
    signal input            kytDepositSignature[3];
    // withdraw case
    signal input            kytWithdrawSignedMessagePackageType;
    signal input            kytWithdrawSignedMessageTimestamp;
    signal input            kytWithdrawSignedMessageSender;
    signal input            kytWithdrawSignedMessageReceiver;
    signal input {uint160}  kytWithdrawSignedMessageToken;
    signal input            kytWithdrawSignedMessageSessionId;
    signal input {uint8}    kytWithdrawSignedMessageRuleId;
    signal input {uint96}   kytWithdrawSignedMessageAmount;
    signal input {uint96}   kytWithdrawSignedMessageChargedAmountZkp;
    signal input {uint160}  kytWithdrawSignedMessageSigner;
    signal input            kytWithdrawSignedMessageHash;
    signal input            kytWithdrawSignature[3];
    // internal case
    signal input            kytSignedMessagePackageType;
    signal input            kytSignedMessageTimestamp;
    signal input            kytSignedMessageSessionId;
    signal input {uint96}   kytSignedMessageChargedAmountZkp;
    signal input {uint160}  kytSignedMessageSigner;
    signal input            kytSignedMessageDataEscrowHash;
    signal input            kytSignedMessageHash;
    signal input            kytSignature[3];
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // START OF CODE /////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [0] - General /////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    var ACTIVE = Active();
    signal extractedToken <== ExtractToken()(kytToken);
    signal kytLeafId <== Uint16Tag(ACTIVE)(Bits2Num(TrustProvidersMerkleTreeDepth)(kytPathIndices));

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [1] - Deposit /////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    component isZeroDeposit = IsZero();
    isZeroDeposit.in <== kytDepositAmount;

    component isKytDepositSignedMessageHashIsZero = IsNotZero();
    isKytDepositSignedMessageHashIsZero.in <== kytDepositSignedMessageHash;

    // in case of swap, we allow to disable kyt-verification check by zero-hash (unless smart-contract side agree to zero-hash)
    signal isKytDepositCheckEnabled <== BinaryTag(ACTIVE)(isSwap ?  isKytDepositSignedMessageHashIsZero.out * (1 - isZeroDeposit.out) : (1 - isZeroDeposit.out));

    component deposit = TrustProvidersDepositWithdrawKyt(IsTestNet);
    deposit.kytRandom <== kytRandom;
    deposit.kytToken <== extractedToken;
    deposit.kytAmount <== kytDepositAmount;
    deposit.kytPubKey <== kytEdDsaPubKey;
    deposit.kytPubKeyExpiryTime <== kytEdDsaPubKeyExpiryTime;
    deposit.zZoneKytExpiryTime <== zZoneKytExpiryTime;
    deposit.createTime <== createTime;
    deposit.kytMasterEOA <== kytMasterEOA;
    deposit.kytMerkleTreeLeafIDsAndRulesOffset <== kytMerkleTreeLeafIDsAndRulesOffset;
    deposit.kytTrustProvidersMerkleTreeLeafIDsAndRulesList <== kytTrustProvidersMerkleTreeLeafIDsAndRulesList;
    deposit.kytLeafId <== kytLeafId;

    deposit.enabled <== isKytDepositCheckEnabled;

    deposit.kytSignedMessagePackageType <== kytDepositSignedMessagePackageType;
    deposit.kytSignedMessageTimestamp <== kytDepositSignedMessageTimestamp;
    deposit.kytSignedMessageSender <== kytDepositSignedMessageSender;
    deposit.kytSignedMessageReceiver <== kytDepositSignedMessageReceiver;
    deposit.kytSignedMessageToken <== kytDepositSignedMessageToken;
    deposit.kytSignedMessageSessionId <== kytDepositSignedMessageSessionId;
    deposit.kytSignedMessageRuleId <== kytDepositSignedMessageRuleId;
    deposit.kytSignedMessageAmount <== kytDepositSignedMessageAmount;
    deposit.kytSignedMessageChargedAmountZkp <== kytDepositSignedMessageChargedAmountZkp;
    deposit.kytSignedMessageSigner <== kytDepositSignedMessageSigner;
    deposit.kytSignedMessageHash <== kytDepositSignedMessageHash;
    deposit.kytSignature <== kytDepositSignature;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [2] - Withdraw ////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    component isZeroWithdraw = IsZero();
    isZeroWithdraw.in <== kytWithdrawAmount;

    component iskytWithdrawSignedMessageHashIsZero = IsNotZero();
    iskytWithdrawSignedMessageHashIsZero.in <== kytWithdrawSignedMessageHash;

    // in case of swap, we allow to disable kyt-verification check by zero-hash (unless smart-contract side agree to zero-hash)
    signal isKytWithdrawCheckEnabled <== BinaryTag(ACTIVE)(isSwap ? iskytWithdrawSignedMessageHashIsZero.out * (1 - isZeroWithdraw.out) : (1 - isZeroWithdraw.out));

    component withdraw = TrustProvidersDepositWithdrawKyt(IsTestNet);
    withdraw.kytRandom <== kytRandom;
    withdraw.kytToken <== extractedToken;
    withdraw.kytAmount <== kytWithdrawAmount;
    withdraw.kytPubKey <== kytEdDsaPubKey;
    withdraw.kytPubKeyExpiryTime <== kytEdDsaPubKeyExpiryTime;
    withdraw.zZoneKytExpiryTime <== zZoneKytExpiryTime;
    withdraw.createTime <== createTime;
    withdraw.kytMasterEOA <== kytMasterEOA;
    withdraw.kytMerkleTreeLeafIDsAndRulesOffset <== kytMerkleTreeLeafIDsAndRulesOffset;
    withdraw.kytTrustProvidersMerkleTreeLeafIDsAndRulesList <== kytTrustProvidersMerkleTreeLeafIDsAndRulesList;
    withdraw.kytLeafId <== kytLeafId;

    withdraw.enabled <== isKytWithdrawCheckEnabled;

    withdraw.kytSignedMessagePackageType <== kytWithdrawSignedMessagePackageType;
    withdraw.kytSignedMessageTimestamp <== kytWithdrawSignedMessageTimestamp;
    withdraw.kytSignedMessageSender <== kytWithdrawSignedMessageSender;
    withdraw.kytSignedMessageReceiver <== kytWithdrawSignedMessageReceiver;
    withdraw.kytSignedMessageToken <== kytWithdrawSignedMessageToken;
    withdraw.kytSignedMessageSessionId <== kytWithdrawSignedMessageSessionId;
    withdraw.kytSignedMessageRuleId <== kytWithdrawSignedMessageRuleId;
    withdraw.kytSignedMessageAmount <== kytWithdrawSignedMessageAmount;
    withdraw.kytSignedMessageChargedAmountZkp <== kytWithdrawSignedMessageChargedAmountZkp;
    withdraw.kytSignedMessageSigner <== kytWithdrawSignedMessageSigner;
    withdraw.kytSignedMessageHash <== kytWithdrawSignedMessageHash;
    withdraw.kytSignature <== kytWithdrawSignature;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [2] - Internal ////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    component isZeroInternal = IsZero();
    isZeroInternal.in <== kytSealing;

    component isKytSignedMessageHashIsZero = IsNotZero();
    isKytSignedMessageHashIsZero.in <== kytSignedMessageHash;

    // internal KYT
    signal isKytInternalCheckEnabled <== BinaryTag(ACTIVE)(isSwap ?  isKytSignedMessageHashIsZero.out * (1 - isZeroInternal.out) : (1 - isZeroInternal.out));

    component internal = TrustProvidersInternalKyt(IsTestNet);
    internal.kytRandom <== kytRandom;
    internal.kytPubKey <== kytEdDsaPubKey;
    internal.kytPubKeyExpiryTime <== kytEdDsaPubKeyExpiryTime;
    internal.zZoneKytExpiryTime <== zZoneKytExpiryTime;
    internal.createTime <== createTime;
    internal.kytMasterEOA <== kytMasterEOA;

    internal.enabled <== isKytInternalCheckEnabled;

    internal.kytSignedMessagePackageType <== kytSignedMessagePackageType;
    internal.kytSignedMessageTimestamp <== kytSignedMessageTimestamp;
    internal.kytSignedMessageSessionId <== kytSignedMessageSessionId;
    internal.kytSignedMessageChargedAmountZkp <== kytSignedMessageChargedAmountZkp;
    internal.kytSignedMessageSigner <== kytSignedMessageSigner;
    internal.kytSignedDepositSignedMessageHash <== kytDepositSignedMessageHash;
    internal.kytSignedWithdrawSignedMessageHash <== kytWithdrawSignedMessageHash;
    internal.kytSignedMessageDataEscrowHash <== kytSignedMessageDataEscrowHash;
    internal.kytSignedMessageHash <== kytSignedMessageHash;
    internal.kytSignature <== kytSignature;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [3] - Inclusion ///////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // result = a+b - a*b
    component isKytCheckEnabled_deposit_withdraw = OR();
    isKytCheckEnabled_deposit_withdraw.a <== isKytDepositCheckEnabled;
    isKytCheckEnabled_deposit_withdraw.b <== isKytWithdrawCheckEnabled;
    // result = a+b - a*b
    component isKytCheckEnabledComponent = OR();
    isKytCheckEnabledComponent.a <== isKytInternalCheckEnabled;
    isKytCheckEnabledComponent.b <== isKytCheckEnabled_deposit_withdraw.out;

    signal isKytCheckEnabled <== isKytCheckEnabledComponent.out;

    // Verify kytEdDSA public key membership
    component kytKycNoteInclusionProver = TrustProvidersNoteInclusionProver(TrustProvidersMerkleTreeDepth);
    kytKycNoteInclusionProver.enabled <== isKytCheckEnabled;
    kytKycNoteInclusionProver.root <== trustProvidersMerkleRoot;
    kytKycNoteInclusionProver.key[0] <== kytEdDsaPubKey[0];
    kytKycNoteInclusionProver.key[1] <== kytEdDsaPubKey[1];
    kytKycNoteInclusionProver.expiryTime <== kytEdDsaPubKeyExpiryTime;
    kytKycNoteInclusionProver.pathIndices <== kytPathIndices;
    kytKycNoteInclusionProver.pathElements <== kytPathElements;
}
