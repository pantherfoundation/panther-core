//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CASE-A ) - if tokenPrivate != zZKP then
//     1) totalAmountIn = deposit + sigma(UTXO-In[i]::Amount)
//     2) totalAmountOut = withdraw + sigma(UTXO-Out[i]::Amount)
//     3) zAccountUtxoOutZkpAmount = zAccountUtxoInZkpAmount - chargedAmountZkp
//
//     ---> AND totalAmountIn === totalAmountOut
//
// CASE-B) - if tokenPrivate == zZKP then
//     1) totalAmountIn = deposit + sigma(UTXO-In[i]::Amount) + zAccountUtxoInZkpAmount
//     2) totalAmountOut = withdraw + sigma(UTXO-Out[i]::Amount) + zAccountUtxoOutZkpAmount + chargedAmountZkp
//     3) zAccountUtxoOutZkpAmount =
//              deposit + sigma(UTXO-In[i]::Amount) + zAccountUtxoInZkpAmount     |||||| totalAmountIn
//              - withdraw - sigma(UTXO-Out[i]::Amount) - chargedAmountZkp        |||||| totalAmountOut
//
//     ---> AND totalAmountIn === totalAmountOut
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
template BalanceChecker() {
    signal input isZkpToken;
    signal input depositAmount;
    signal input withdrawAmount;
    signal input chargedAmountZkp;
    signal input zAccountUtxoInZkpAmount;
    signal input zAccountUtxoOutZkpAmount;
    signal input totalUtxoInAmount;
    signal input totalUtxoOutAmount;
    signal input zAssetWeight;
    signal input zAssetScale;
    signal output totalScaled;
    signal output totalWeighted;
    signal output depositScaledAmount;
    signal output depositWeightedScaledAmount;
    signal output depositChange;
    signal output withdrawScaledAmount;
    signal output withdrawWeightedScaledAmount;
    signal output withdrawChange;

    // Scale external amounts
    var zAssetScaleFactor = 10**zAssetScale;
    // 1 - deposit
    signal depositScaledAmountTmp;
    depositScaledAmountTmp <-- depositAmount \ zAssetScaleFactor;
    depositScaledAmount <== depositScaledAmountTmp;
    signal depositAmountRestored;
    depositAmountRestored <-- depositScaledAmount * zAssetScaleFactor;

    depositChange <== depositAmount - depositAmountRestored;
    depositWeightedScaledAmount <== depositScaledAmountTmp * zAssetWeight;

    // 2 - withdraw
    signal withdrawScaledAmountTmp;
    withdrawScaledAmountTmp <-- withdrawAmount \ zAssetScaleFactor;
    withdrawScaledAmount <== withdrawScaledAmountTmp;
    signal withdrawAmountRestored;
    withdrawAmountRestored <-- withdrawScaledAmount * zAssetScaleFactor;

    withdrawChange <== withdrawAmount - withdrawAmountRestored;
    withdrawWeightedScaledAmount <== withdrawScaledAmountTmp * zAssetWeight;


    // Verify total balances
    signal totalBalanceIn;
    totalBalanceIn <== depositScaledAmount + totalUtxoInAmount + isZkpToken * zAccountUtxoInZkpAmount;

    signal totalBalanceOut;
    totalBalanceOut <== withdrawScaledAmount + totalUtxoOutAmount + isZkpToken * ( zAccountUtxoOutZkpAmount + chargedAmountZkp );

    component isEqual = IsEqual();
    isEqual.in[0] <== totalBalanceIn;
    isEqual.in[1] <== totalBalanceOut;

    // Verify zAccountUtxoOutZkpAmount
    component zAccountUtxoOutZkpAmountChecker = ForceEqualIfEnabled();
    // disabled if zZKP token since if zZKP the balance is checked via totalBalance IN/OUT
    zAccountUtxoOutZkpAmountChecker.enabled <== 1 - isZkpToken;
    zAccountUtxoOutZkpAmountChecker.in[0] <== zAccountUtxoOutZkpAmount;
    zAccountUtxoOutZkpAmountChecker.in[1] <== zAccountUtxoInZkpAmount - chargedAmountZkp;

    totalScaled <== totalBalanceIn;
    totalWeighted <== totalBalanceIn * zAssetWeight;
}


