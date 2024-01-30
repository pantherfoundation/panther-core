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
    signal input donatedAmountZkp;
    signal input zAccountUtxoInZkpAmount;
    signal input zAccountUtxoOutZkpAmount;
    signal input totalUtxoInAmount;
    signal input totalUtxoOutAmount;
    signal input zAssetWeight;
    signal input zAssetScale;
    signal input zAssetScaleZkp;
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

    // [1.3] - scaled zZKP donation
    assert(zAssetScaleZkp > 0);
    signal donatedScaledAmountZkp;
    donatedScaledAmountZkp <-- donatedAmountZkp \ zAssetScaleZkp;
    donatedAmountZkp === donatedScaledAmountZkp * zAssetScaleZkp;
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

    // [2.3] - scaled zZKP charge
    signal chargedScaledAmountZkp;
    chargedScaledAmountZkp <-- chargedAmountZkp \ zAssetScaleZkp;
    chargedAmountZkp === chargedScaledAmountZkp * zAssetScaleZkp;
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Withdraw /////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [3] - Verify total balances /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    signal totalBalanceIn;
    totalBalanceIn <== depositScaledAmount + totalUtxoInAmount + isZkpToken * ( zAccountUtxoInZkpAmount + donatedScaledAmountZkp );

    signal totalBalanceOut;
    totalBalanceOut <== withdrawScaledAmount + totalUtxoOutAmount + isZkpToken * ( zAccountUtxoOutZkpAmount + chargedScaledAmountZkp );

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
    zAccountUtxoOutZkpAmountChecker.in[0] <== zAccountUtxoInZkpAmount + donatedScaledAmountZkp;
    zAccountUtxoOutZkpAmountChecker.in[1] <== zAccountUtxoOutZkpAmount + chargedScaledAmountZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [5] - Compute scaled & weighted /////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [5.0] - check if IN =< OUT
    component lessThen = LessEqThan(252);
    lessThen.in[0] <== zAccountUtxoInZkpAmount;
    lessThen.in[1] <== zAccountUtxoOutZkpAmount;

    // [5.1] - choose IN if IN < OUT, choose OUT if OUT < IN
    signal mux_input[2];
    mux_input[0] <== lessThen.out * zAccountUtxoInZkpAmount;        // NOT zero if IN =< OUT
    mux_input[1] <== (1 - lessThen.out) * zAccountUtxoOutZkpAmount; // NOT zero if OUT < IN

    signal zAccountUtxoResidualZkpAmount <== mux_input[0] + mux_input[1];
    // [5.2] - compute total-scaled with respect to zAccount balance in case of zZKP token
    totalScaled <== totalBalanceIn - ( isZkpToken * zAccountUtxoResidualZkpAmount );
    totalWeighted <== totalScaled * zAssetWeight;
}


