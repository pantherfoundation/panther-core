//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

include "../../circuits/templates/balanceChecker.circom";
include "../../circuits/templates/utils.circom";

template BalanceCheckerTop () {
    signal input isZkpToken;
    signal input depositAmount;
    signal input withdrawAmount;
    signal input chargedAmountZkp;
    signal input addedAmountZkp;
    signal input zAccountUtxoInZkpAmount;
    signal input zAccountUtxoOutZkpAmount;
    signal input totalUtxoInAmount;
    signal input totalUtxoOutAmount;
    signal input zAssetWeight;
    signal input zAssetScale;
    signal input zAssetScaleZkp;
    signal input kytDepositChargedAmountZkp;
    signal input kytWithdrawChargedAmountZkp;
    signal input kytInternalChargedAmountZkp;
    signal output depositScaledAmount;
    signal output depositWeightedScaledAmount;
    signal output withdrawScaledAmount;
    signal output withdrawWeightedScaledAmount;
    signal output totalScaled;
    signal output totalWeighted;

    var ACTIVE = Active();
    var IGNORE_ANCHORED = NonActive();
    var IGNORE_CONSTANT = NonActive();

    signal rc_isZkpToken <== BinaryTag(IGNORE_ANCHORED)(isZkpToken);
    signal rc_depositAmount <== Uint96Tag(IGNORE_CONSTANT)(depositAmount);
    signal rc_withdrawAmount <== Uint96Tag(IGNORE_CONSTANT)(withdrawAmount);
    signal rc_chargedAmountZkp <== Uint96Tag(IGNORE_CONSTANT)(chargedAmountZkp);
    signal rc_addedAmountZkp <== Uint96Tag(IGNORE_CONSTANT)(addedAmountZkp);
    signal rc_zAccountUtxoInZkpAmount <== Uint64Tag(IGNORE_CONSTANT)(zAccountUtxoInZkpAmount);
    signal rc_zAccountUtxoOutZkpAmount <== Uint64Tag(IGNORE_CONSTANT)(zAccountUtxoOutZkpAmount);
    signal rc_totalUtxoInAmount <== Uint70Tag(IGNORE_CONSTANT)(totalUtxoInAmount);
    signal rc_totalUtxoOutAmount <== Uint70Tag(IGNORE_CONSTANT)(totalUtxoOutAmount);
    signal rc_zAssetWeight <== NonZeroUint48Tag(IGNORE_ANCHORED)(zAssetWeight);
    signal rc_zAssetScale <== NonZeroUint64Tag(IGNORE_ANCHORED)(zAssetScale);
    signal rc_zAssetScaleZkp <== NonZeroUint64Tag(IGNORE_ANCHORED)(zAssetScaleZkp);
    signal rc_kytDepositChargedAmountZkp <== Uint96Tag(IGNORE_CONSTANT)(kytDepositChargedAmountZkp);
    signal rc_kytWithdrawChargedAmountZkp <== Uint96Tag(IGNORE_CONSTANT)(kytWithdrawChargedAmountZkp);
    signal rc_kytInternalChargedAmountZkp <== Uint96Tag(IGNORE_CONSTANT)(kytInternalChargedAmountZkp);

    component balanceChecker = BalanceChecker();
    balanceChecker.isZkpToken <== rc_isZkpToken;
    balanceChecker.depositAmount <== rc_depositAmount;
    balanceChecker.withdrawAmount <== rc_withdrawAmount;
    balanceChecker.chargedAmountZkp <== rc_chargedAmountZkp;
    balanceChecker.addedAmountZkp <== rc_addedAmountZkp;
    balanceChecker.zAccountUtxoInZkpAmount <== rc_zAccountUtxoInZkpAmount;
    balanceChecker.zAccountUtxoOutZkpAmount <== rc_zAccountUtxoOutZkpAmount;
    balanceChecker.totalUtxoInAmount <== rc_totalUtxoInAmount;
    balanceChecker.totalUtxoOutAmount <== rc_totalUtxoOutAmount;
    balanceChecker.zAssetWeight <== rc_zAssetWeight;
    balanceChecker.zAssetScale <== rc_zAssetScale;
    balanceChecker.zAssetScaleZkp <== rc_zAssetScaleZkp;
    balanceChecker.kytDepositChargedAmountZkp <== rc_kytDepositChargedAmountZkp;
    balanceChecker.kytWithdrawChargedAmountZkp <== rc_kytWithdrawChargedAmountZkp;
    balanceChecker.kytInternalChargedAmountZkp <== rc_kytInternalChargedAmountZkp;
}
