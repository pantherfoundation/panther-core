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
    signal input depositChange;
    signal input withdrawAmount;
    signal input withdrawChange;
    signal input chargedAmountZkp;
    signal input zAccountUtxoInZkpAmount;
    signal input zAccountUtxoOutZkpAmount;
    signal input totalUtxoInAmount;
    signal input totalUtxoOutAmount;
    signal input zAssetWeight;
    signal input zAssetScale;
    signal output depositScaledAmount;
    signal output depositWeightedScaledAmount;
    signal output withdrawWeightedScaledAmount;
    signal output withdrawScaledAmount;
    signal output totalScaled;
    signal output totalWeighted;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [1] - Deposit ///////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assert(zAssetScale > 0);

    // If depositAmount is 0 then depositChange must be 0
    component isZeroDeposit = IsZero();
    isZeroDeposit.in <== depositAmount;

    component isDepositAndChangeEqual = ForceEqualIfEnabled();
    isDepositAndChangeEqual.in[0] <== depositAmount;
    isDepositAndChangeEqual.in[1] <== depositChange;
    isDepositAndChangeEqual.enabled <== isZeroDeposit.out;

    // [1.0] - scale ( a / b = c )
    signal depositScaledAmountTmp;
    depositScaledAmountTmp <-- depositAmount \ zAssetScale;
    depositScaledAmount <== depositScaledAmountTmp;

    // [1.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a + reminder )
    depositAmount === ( depositScaledAmountTmp * zAssetScale ) + depositChange;

    // [1.2] - weighted amount
    depositWeightedScaledAmount <== depositScaledAmountTmp * zAssetWeight;
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Deposit //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [2] - Withdraw //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // If withdrawAmount is 0 then withdrawChange must be 0
    component isZeroWithdraw = IsZero();
    isZeroWithdraw.in <== withdrawAmount;

    component isWithdrawAndChangeEqual = ForceEqualIfEnabled();
    isWithdrawAndChangeEqual.in[0] <== withdrawAmount;
    isWithdrawAndChangeEqual.in[1] <== withdrawChange;
    isWithdrawAndChangeEqual.enabled <== isZeroWithdraw.out;

    // [2.0] - scale ( a / b = c )
    signal withdrawScaledAmountTmp;
    withdrawScaledAmountTmp <-- withdrawAmount \ zAssetScale;
    withdrawScaledAmount <== withdrawScaledAmountTmp;

    // [2.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a + reminder )
    withdrawAmount === ( withdrawScaledAmountTmp * zAssetScale ) + withdrawChange;

    // [2.2] - weighted amount
    withdrawWeightedScaledAmount <== withdrawScaledAmountTmp * zAssetWeight;
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Withdraw /////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [3] - Verify total balances /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    signal totalBalanceIn;
    totalBalanceIn <== depositScaledAmount + totalUtxoInAmount + isZkpToken * zAccountUtxoInZkpAmount;

    signal totalBalanceOut;
    totalBalanceOut <== withdrawScaledAmount + totalUtxoOutAmount + isZkpToken * ( zAccountUtxoOutZkpAmount + chargedAmountZkp );

    component totalBalanceIsEqual = ForceEqualIfEnabled();
    totalBalanceIsEqual.enabled <== 1; // always enabled
    totalBalanceIsEqual.in[0] <== totalBalanceIn;
    totalBalanceIsEqual.in[1] <== totalBalanceOut;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [4] - Verify zAccountUtxoOutZkpAmount ///////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    component zAccountUtxoOutZkpAmountChecker = ForceEqualIfEnabled();
    // disabled if zZKP token since if zZKP the balance is checked via totalBalance IN/OUT
    zAccountUtxoOutZkpAmountChecker.enabled <== 1 - isZkpToken;
    zAccountUtxoOutZkpAmountChecker.in[0] <== zAccountUtxoOutZkpAmount;
    zAccountUtxoOutZkpAmountChecker.in[1] <== zAccountUtxoInZkpAmount - chargedAmountZkp;

    totalScaled <== totalBalanceIn;
    totalWeighted <== totalBalanceIn * zAssetWeight;
}


