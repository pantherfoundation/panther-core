//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../circuits/templates/zAssetChecker.circom";
include "../../circuits/templates/utils.circom";

template ZAssetCheckerTop () {
    signal input token;
    signal input tokenId;
    signal input zAssetId;
    signal input zAssetToken;
    signal input zAssetTokenId;
    signal input zAssetOffset;
    signal input depositAmount;
    signal input withdrawAmount;
    signal input utxoZAssetId;
    signal output isZkpToken;

    var ACTIVE = Active();
    var IGNORE_ANCHORED = NonActive();
    var IGNORE_PUBLIC = NonActive();

    signal rc_token <== Uint168Tag(IGNORE_ANCHORED)(token);
    signal rc_tokenId <== Uint252Tag(IGNORE_ANCHORED)(tokenId);
    signal rc_zAssetId <== Uint64Tag(IGNORE_ANCHORED)(zAssetId);
    signal rc_zAssetToken <== Uint168Tag(IGNORE_ANCHORED)(zAssetToken);
    signal rc_zAssetTokenId <== Uint252Tag(IGNORE_ANCHORED)(zAssetTokenId);
    signal rc_zAssetOffset <== Uint32Tag(IGNORE_ANCHORED)(zAssetOffset);
    signal rc_depositAmount <== Uint96Tag(IGNORE_PUBLIC)(depositAmount);
    signal rc_withdrawAmount <== Uint96Tag(IGNORE_PUBLIC)(withdrawAmount);
    signal rc_utxoZAssetId <== Uint64Tag(IGNORE_ANCHORED)(utxoZAssetId);

    component zAssetChecker = ZAssetChecker();
    zAssetChecker.token <== rc_token;
    zAssetChecker.tokenId <== rc_tokenId;
    zAssetChecker.zAssetId <== rc_zAssetId;
    zAssetChecker.zAssetToken <== rc_zAssetToken;
    zAssetChecker.zAssetTokenId <== rc_zAssetTokenId;
    zAssetChecker.zAssetOffset <== rc_zAssetOffset;
    zAssetChecker.depositAmount <== rc_depositAmount;
    zAssetChecker.withdrawAmount <== rc_withdrawAmount;
    zAssetChecker.utxoZAssetId <== rc_utxoZAssetId;
}
