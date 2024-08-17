pragma circom 2.1.9;

include "./templates/utils.circom";

template ZZZ(isSwap,TrustProvidersMerkleTreeDepth) {
    signal input {uint160}        kytToken;
    signal input {uint96}         kytDepositAmount;
    signal input {uint96}         kytWithdrawAmount;
    signal input {uint160}        kytMasterEOA;
    signal input {uint240}        kytTrustProvidersMerkleTreeLeafIDsAndRulesList;
    signal input {binary}         kytSealing;
//
    signal input {sub_order_bj_p} kytEdDsaPubKey[2];
    signal input {uint32}         kytEdDsaPubKeyExpiryTime;
    signal input {uint32}         createTime;
    signal input {uint32}         zZoneKytExpiryTime;
    signal input                  trustProvidersMerkleRoot;
    signal input                  kytPathElements[TrustProvidersMerkleTreeDepth];
    signal input {binary}         kytPathIndices[TrustProvidersMerkleTreeDepth];
    signal input {uint4}          kytMerkleTreeLeafIDsAndRulesOffset;
//
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
//
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
//
    signal input            kytSignedMessagePackageType;
    signal input            kytSignedMessageTimestamp;
    signal input            kytSignedMessageSessionId;
    signal input {uint96}   kytSignedMessageChargedAmountZkp;
    signal input {uint160}  kytSignedMessageSigner;
    signal input            kytSignedMessageDataEscrowHash;
    signal input            kytSignedMessageHash;
    signal input            kytSignature[3];
}

template ZZZTop(isSwap,TrustProvidersMerkleTreeDepth) {
    signal input       kytToken;
    signal input       kytDepositAmount;
    signal input       kytWithdrawAmount;
    signal input       kytMasterEOA;
    signal input       kytTrustProvidersMerkleTreeLeafIDsAndRulesList;
    signal input       kytSealing;

    // KYC-KYT
    // to switch-off:
    //      1) depositAmount = 0
    //      2) withdrawAmount = 0
    // Note: for swap case, kyt-hash = zero also can switch-off the KYT verification check
    // switch-off control is used for internal tx
    signal input kytEdDsaPubKey[2];
    signal input kytEdDsaPubKeyExpiryTime;
    signal input zZoneKytExpiryTime;
    signal input createTime;
    signal input trustProvidersMerkleRoot;
    signal input kytPathElements[TrustProvidersMerkleTreeDepth];
    signal input kytPathIndices[TrustProvidersMerkleTreeDepth];
    signal input kytMerkleTreeLeafIDsAndRulesOffset;

    // deposit case
    signal input  kytDepositSignedMessagePackageType;
    signal input  kytDepositSignedMessageTimestamp;
    signal input  kytDepositSignedMessageSender;
    signal input  kytDepositSignedMessageReceiver;
    signal input  kytDepositSignedMessageToken;
    signal input  kytDepositSignedMessageSessionId;
    signal input  kytDepositSignedMessageRuleId;
    signal input  kytDepositSignedMessageAmount;
    signal input  kytDepositSignedMessageChargedAmountZkp;
    signal input  kytDepositSignedMessageSigner;
    signal input  kytDepositSignedMessageHash;
    signal input  kytDepositSignature[3];
    // withdraw c
    signal input  kytWithdrawSignedMessagePackageType;
    signal input  kytWithdrawSignedMessageTimestamp;
    signal input  kytWithdrawSignedMessageSender;
    signal input  kytWithdrawSignedMessageReceiver;
    signal input  kytWithdrawSignedMessageToken;
    signal input  kytWithdrawSignedMessageSessionId;
    signal input  kytWithdrawSignedMessageRuleId;
    signal input  kytWithdrawSignedMessageAmount;
    signal input  kytWithdrawSignedMessageChargedAmountZkp;
    signal input  kytWithdrawSignedMessageSigner;
    signal input  kytWithdrawSignedMessageHash;
    signal input  kytWithdrawSignature[3];
    // internal c
    signal input  kytSignedMessagePackageType;
    signal input  kytSignedMessageTimestamp;
    signal input  kytSignedMessageSessionId;
    signal input  kytSignedMessageChargedAmountZkp;
    signal input  kytSignedMessageSigner;
    signal input  kytSignedMessageDataEscrowHash;
    signal input  kytSignedMessageHash;
    signal input  kytSignature[3];

    component RC = ZZZ(isSwap,TrustProvidersMerkleTreeDepth);
    RC.kytToken <== Uint160Tag(1)(kytToken);
    RC.kytDepositAmount <== Uint96Tag(1)(kytDepositAmount);
    RC.kytWithdrawAmount <== Uint96Tag(1)(kytWithdrawAmount);
    RC.kytMasterEOA <== Uint160Tag(1)(kytMasterEOA);
    RC.kytTrustProvidersMerkleTreeLeafIDsAndRulesList <== Uint240Tag(1)(kytTrustProvidersMerkleTreeLeafIDsAndRulesList);
    RC.kytSealing <== BinaryTag(1)(kytSealing);

    RC.kytEdDsaPubKey <== BabyJubJubSubGroupPointTag(1)(kytEdDsaPubKey);
    RC.kytEdDsaPubKeyExpiryTime <== Uint32Tag(1)(kytEdDsaPubKeyExpiryTime);
    RC.createTime <==  Uint32Tag(1)(createTime);
    RC.zZoneKytExpiryTime <==  Uint32Tag(1)(zZoneKytExpiryTime);
    RC.trustProvidersMerkleRoot <== trustProvidersMerkleRoot;
    RC.kytPathElements <== kytPathElements;
    RC.kytPathIndices <== BinaryTagArray(1,16)(kytPathIndices);
    RC.kytMerkleTreeLeafIDsAndRulesOffset <== Uint4Tag(1)(kytMerkleTreeLeafIDsAndRulesOffset);
//
    RC.kytDepositSignedMessagePackageType <== kytDepositSignedMessagePackageType;
    RC.kytDepositSignedMessageTimestamp <== kytDepositSignedMessageTimestamp;
    RC.kytDepositSignedMessageSender <== kytDepositSignedMessageSender;
    RC.kytDepositSignedMessageReceiver <== kytDepositSignedMessageReceiver;
    RC.kytDepositSignedMessageToken <== Uint160Tag(1)(kytDepositSignedMessageToken);
    RC.kytDepositSignedMessageSessionId <== kytDepositSignedMessageSessionId;
    RC.kytDepositSignedMessageRuleId <== Uint8Tag(1)(kytDepositSignedMessageRuleId);
    RC.kytDepositSignedMessageAmount <== Uint96Tag(1)(kytDepositSignedMessageAmount);
    RC.kytDepositSignedMessageChargedAmountZkp <== Uint96Tag(1)(kytDepositSignedMessageChargedAmountZkp);
    RC.kytDepositSignedMessageSigner <== Uint160Tag(1)(kytDepositSignedMessageSigner);
    RC.kytDepositSignedMessageHash <== kytDepositSignedMessageHash;
    RC.kytDepositSignature <== kytDepositSignature;
//
    RC.kytWithdrawSignedMessagePackageType <== kytWithdrawSignedMessagePackageType;
    RC.kytWithdrawSignedMessageTimestamp <== kytWithdrawSignedMessageTimestamp;
    RC.kytWithdrawSignedMessageSender <== kytWithdrawSignedMessageSender;
    RC.kytWithdrawSignedMessageReceiver <== kytWithdrawSignedMessageReceiver;
    RC.kytWithdrawSignedMessageToken <== Uint160Tag(1)(kytWithdrawSignedMessageToken);
    RC.kytWithdrawSignedMessageSessionId <== kytWithdrawSignedMessageSessionId;
    RC.kytWithdrawSignedMessageRuleId <== Uint8Tag(1)(kytWithdrawSignedMessageRuleId);
    RC.kytWithdrawSignedMessageAmount <== Uint96Tag(1)(kytWithdrawSignedMessageAmount);
    RC.kytWithdrawSignedMessageChargedAmountZkp <== Uint96Tag(1)(kytWithdrawSignedMessageChargedAmountZkp);
    RC.kytWithdrawSignedMessageSigner <== Uint160Tag(1)(kytWithdrawSignedMessageSigner);
    RC.kytWithdrawSignedMessageHash <== kytWithdrawSignedMessageHash;
    RC.kytWithdrawSignature <== kytWithdrawSignature;
//
    RC.kytSignedMessagePackageType <== kytSignedMessagePackageType;
    RC.kytSignedMessageTimestamp <== kytSignedMessageTimestamp;
    RC.kytSignedMessageSessionId <== kytSignedMessageSessionId;
    RC.kytSignedMessageChargedAmountZkp <== Uint96Tag(1)(kytSignedMessageChargedAmountZkp);
    RC.kytSignedMessageSigner <== Uint160Tag(1)(kytSignedMessageSigner);
    RC.kytSignedMessageDataEscrowHash <== kytSignedMessageDataEscrowHash;
    RC.kytSignedMessageHash <== kytSignedMessageHash;
    RC.kytSignature <== kytSignature;
}
component main = ZZZTop(1,16);
