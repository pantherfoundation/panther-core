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

    // Audit Bug - 4.1.1 V-PANC-VUL-001: depositScaledAmount is under-constrained
    component depositScaledAmountTmpOverflow = LessThan(252);
    depositScaledAmountTmpOverflow.in[0] <== depositScaledAmountTmp;
    depositScaledAmountTmpOverflow.in[1] <== 2**252;
    depositScaledAmountTmpOverflow.out === 1;

    depositScaledAmount <== depositScaledAmountTmp;

    // [1.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a + reminder )
    depositAmount === ( depositScaledAmountTmp * zAssetScale ) + depositChange;

    // [1.2] - weighted amount
    depositWeightedScaledAmount <== depositScaledAmountTmp * zAssetWeight;

    // [1.3] - scaled zZKP donation
    assert(zAssetScaleZkp > 0);
    signal addedScaledAmountZkp;
    addedScaledAmountZkp <-- addedAmountZkp \ zAssetScaleZkp;

    // Audit Bug - 4.1.4 V-PANC-VUL-004: donatedScaledAmountZkp is under-constrained
    component addedScaledAmountZkpOverflow = LessThan(252);
    addedScaledAmountZkpOverflow.in[0] <== addedScaledAmountZkp;
    addedScaledAmountZkpOverflow.in[1] <== 2**252;
    addedScaledAmountZkpOverflow.out === 1;

    addedAmountZkp === addedScaledAmountZkp * zAssetScaleZkp;

    // [1.4] - scaled zZKP deposit KYT amount
    signal kytDepositScaledChargedAmountZkp;
    kytDepositScaledChargedAmountZkp <-- kytDepositChargedAmountZkp \ zAssetScaleZkp;

    component kytDepositScaledChargedAmountZkpOverflow = LessThan(252);
    kytDepositScaledChargedAmountZkpOverflow.in[0] <== kytDepositScaledChargedAmountZkp;
    kytDepositScaledChargedAmountZkpOverflow.in[1] <== 2**252;
    kytDepositScaledChargedAmountZkpOverflow.out === 1;

    kytDepositChargedAmountZkp === kytDepositScaledChargedAmountZkp * zAssetScaleZkp;

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

    // Audit Bug - 4.1.3 V-PANC-VUL-003: withdrawScaledAmount is under-constrained
    component withdrawScaledAmountTmpOverflow = LessThan(252);
    withdrawScaledAmountTmpOverflow.in[0] <== withdrawScaledAmountTmp;
    withdrawScaledAmountTmpOverflow.in[1] <== 2**252;
    withdrawScaledAmountTmpOverflow.out === 1;

    withdrawScaledAmount <== withdrawScaledAmountTmp;

    // [2.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a + reminder )
    withdrawAmount === ( withdrawScaledAmountTmp * zAssetScale ) + withdrawChange;

    // [2.2] - weighted amount
    withdrawWeightedScaledAmount <== withdrawScaledAmountTmp * zAssetWeight;

    // [2.3] - scaled zZKP charge
    signal chargedScaledAmountZkp;
    chargedScaledAmountZkp <-- chargedAmountZkp \ zAssetScaleZkp;

    // Audit Bug - 4.1.6 V-PANC-VUL-006: chargedScaledAmountZkp is under-constrained
    component chargedScaledAmountZkpOverflow = LessThan(252);
    chargedScaledAmountZkpOverflow.in[0] <== chargedScaledAmountZkp;
    chargedScaledAmountZkpOverflow.in[1] <== 2**252;
    chargedScaledAmountZkpOverflow.out === 1;

    chargedAmountZkp === chargedScaledAmountZkp * zAssetScaleZkp;

    // [2.4] - scaled zZKP deposit KYT amount
    signal kytWithdrawScaledChargedAmountZkp;
    kytWithdrawScaledChargedAmountZkp <-- kytWithdrawChargedAmountZkp \ zAssetScaleZkp;

    component kytWithdrawScaledChargedAmountZkpOverflow = LessThan(252);
    kytWithdrawScaledChargedAmountZkpOverflow.in[0] <== kytWithdrawScaledChargedAmountZkp;
    kytWithdrawScaledChargedAmountZkpOverflow.in[1] <== 2**252;
    kytWithdrawScaledChargedAmountZkpOverflow.out === 1;

    kytWithdrawChargedAmountZkp === kytWithdrawScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Withdraw /////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [3] - scaled zZKP internal KYT amount ///////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    signal kytInternalScaledChargedAmountZkp;
    kytInternalScaledChargedAmountZkp <-- kytInternalChargedAmountZkp \ zAssetScaleZkp;

    component kytInternalScaledChargedAmountZkpOverflow = LessThan(252);
    kytInternalScaledChargedAmountZkpOverflow.in[0] <== kytInternalScaledChargedAmountZkp;
    kytInternalScaledChargedAmountZkpOverflow.in[1] <== 2**252;
    kytInternalScaledChargedAmountZkpOverflow.out === 1;

    kytInternalChargedAmountZkp === kytInternalScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [4] - Verify total balances /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    signal kytChargedScaledAmountZkp;
    kytChargedScaledAmountZkp <== kytDepositScaledChargedAmountZkp + kytWithdrawScaledChargedAmountZkp + kytInternalChargedAmountZkp;

    component kytChargedScaledAmountZkpCheck = LessThan(252);
    kytChargedScaledAmountZkpCheck.in[0] <== kytChargedScaledAmountZkp;
    kytChargedScaledAmountZkpCheck.in[1] <== 2**252;
    kytChargedScaledAmountZkpCheck.out === 1;

    signal totalBalanceIn;
    totalBalanceIn <== depositScaledAmount + totalUtxoInAmount + isZkpToken * ( zAccountUtxoInZkpAmount + addedScaledAmountZkp );

    signal totalBalanceOut;
    totalBalanceOut <== withdrawScaledAmount + totalUtxoOutAmount + isZkpToken * ( zAccountUtxoOutZkpAmount + chargedScaledAmountZkp + kytChargedScaledAmountZkp );

    component totalBalanceIsEqual = ForceEqualIfEnabled();
    totalBalanceIsEqual.enabled <== 1; // always enabled
    totalBalanceIsEqual.in[0] <== totalBalanceIn;
    totalBalanceIsEqual.in[1] <== totalBalanceOut;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [5] - Verify zAccountUtxoOutZkpAmount ///////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    component zAccountUtxoOutZkpAmountChecker = ForceEqualIfEnabled();
    // disabled if zZKP token since if zZKP the balance is checked via totalBalance IN/OUT
    zAccountUtxoOutZkpAmountChecker.enabled <== 1 - isZkpToken;
    zAccountUtxoOutZkpAmountChecker.in[0] <== zAccountUtxoInZkpAmount + addedScaledAmountZkp;
    zAccountUtxoOutZkpAmountChecker.in[1] <== zAccountUtxoOutZkpAmount + chargedScaledAmountZkp + kytChargedScaledAmountZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [6] - Compute scaled & weighted /////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [6.0] - check if IN =< OUT
    component lessThen = LessEqThan(252);
    lessThen.in[0] <== zAccountUtxoInZkpAmount;
    lessThen.in[1] <== zAccountUtxoOutZkpAmount;

    // [6.1] - choose IN if IN < OUT, choose OUT if OUT < IN
    signal mux_input[2];
    mux_input[0] <== lessThen.out * zAccountUtxoInZkpAmount;        // NOT zero if IN =< OUT
    mux_input[1] <== (1 - lessThen.out) * zAccountUtxoOutZkpAmount; // NOT zero if OUT < IN

    signal zAccountUtxoResidualZkpAmount <== mux_input[0] + mux_input[1];
    // [6.2] - compute total-scaled with respect to zAccount balance in case of zZKP token
    totalScaled <== totalBalanceIn - ( isZkpToken * zAccountUtxoResidualZkpAmount );

    // Audit Bug - 4.1.2 V-PANC-VUL-002: zkpScaledAmount is under-constrained
    component totalScaledOverflow = LessThan(252);
    totalScaledOverflow.in[0] <== totalScaled;
    totalScaledOverflow.in[1] <== 2**252;
    totalScaledOverflow.out === 1;

    totalWeighted <== totalScaled * zAssetWeight;
}
