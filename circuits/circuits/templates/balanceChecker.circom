//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "./utils.circom";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CASE-A ) - if tokenPrivate != zZKP then
//     1) totalAmountIn = deposit + sigma(UTXO-In[i]::Amount)
//     2) totalAmountOut = withdraw + sigma(UTXO-Out[i]::Amount)
//     3) totalAmountZkpIn = zAccountUtxoInZkpAmount + addedAmountZkp
//     4) totalAmountZkpOut = zAccountUtxoOutZkpAmount + chargedAmountZkp + kytChargedAmountZkp
//
//     ---> AND totalAmountIn === totalAmountOut
//     ---> AND totalAmountZkpIn === totalAmountZkpOut
//
// CASE-B) - if tokenPrivate == zZKP then
//     1) totalAmountIn = deposit + sigma(UTXO-In[i]::Amount) + zAccountUtxoInZkpAmount + addedAmountZkp
//     2) totalAmountOut = withdraw + sigma(UTXO-Out[i]::Amount) + zAccountUtxoOutZkpAmount + chargedAmountZkp + kytChargedAmountZkp
//
//     ---> AND totalAmountIn === totalAmountOut
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
template BalanceChecker() {
    signal input isZkpToken;                        // binary-tag, assumed to be: 0 - 1
    signal input depositAmount;                     // public-tag, assumed to be: 0 - 2^96
    signal input depositChange;                     // assumed-tag, equal to zero
    signal input withdrawAmount;                    // public-tag, assumed to be: 0 - 2^96
    signal input withdrawChange;                    // assumed-tag, equal to zero
    signal input chargedAmountZkp;                  // public-tag, assumed to be: 0 - 2^96
    signal input addedAmountZkp;                    // public-tag, assumed to be: 0 - 2^96
    signal input zAccountUtxoInZkpAmount;           // anchored-tag, assumed to be: 0 - 2^64
    signal input zAccountUtxoOutZkpAmount;          // anchored-tag, assumed to be: 0 - 2^64
    signal input totalUtxoInAmount;                 // anchored-tag, assumed to be: 0 - nUtxoIn x 2^64 < 2^70
    signal input totalUtxoOutAmount;                // anchored-tag, assumed to be: 0 - nUtxoOut x 2^64 < 2^70
    signal input zAssetWeight;                      // anchored-tag, assumed to be: 1 - 2^32
    signal input zAssetScale;                       // anchored-tag, assumed to be: 1 - 2^64
    signal input zAssetScaleZkp;                    // anchored-tag, assumed to be: 1 - 2^64
    signal input kytDepositChargedAmountZkp;        // range-check-tag, assumed to be: 0 - 2^96
    signal input kytWithdrawChargedAmountZkp;       // range-check-tag, assumed to be: 0 - 2^96
    signal input kytInternalChargedAmountZkp;       // range-check-tag, assumed to be: 0 - 2^96
    signal output depositScaledAmount;              // range-check-tag,, assumed to be: 0 - 2^64
    signal output depositWeightedScaledAmount;      // range-check-tag, assumed to be: 0 - 2^96
    signal output withdrawScaledAmount;             // range-check-tag, assumed to be: 0 - 2^64
    signal output withdrawWeightedScaledAmount;     // range-check-tag, assumed to be: 0 - 2^96
    signal output totalScaled;                      // range-check-tag, assumed to be: 0 - 2^96
    signal output totalWeighted;                    // range-check-tag, assumed to be: 0 - 2^96
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [0] - Asserts ///////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assert(0 <= isZkpToken < 2);
    assert(0 <= depositAmount < 2**96);
    assert(depositChange == 0);
    assert(0 <= withdrawAmount < 2**96);
    assert(withdrawChange == 0);
    assert(0 <= addedAmountZkp < 2**96);
    assert(0 <= chargedAmountZkp < 2**96);
    assert(0 <= zAccountUtxoInZkpAmount < 2**64);
    assert(0 <= zAccountUtxoOutZkpAmount < 2**64);
    assert(0 <= totalUtxoInAmount < 2**70);
    assert(0 <= totalUtxoOutAmount < 2**70);
    assert(0 <= zAssetWeight < 2**32);
    assert(0 <= zAssetScale < 2**64);
    assert(0 <= zAssetScaleZkp < 2**64);
    assert(0 <= kytDepositChargedAmountZkp < 2**96);
    assert(0 <= kytWithdrawChargedAmountZkp < 2**96);
    assert(0 <= kytInternalChargedAmountZkp < 2**96);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [1] - Deposit ///////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assert(zAssetScale > 0);      // this value is anchored inside zAsset MT, so no need to RC greater then zero
    assert(zAssetScale < 2**64);  // this value needs to be range-checked

    // If depositAmount is 0 then depositChange must be 0
    component isZeroDeposit = IsZero();
    isZeroDeposit.in <== depositAmount;

    component isDepositAndChangeEqual = ForceEqualIfEnabled();
    isDepositAndChangeEqual.in[0] <== depositAmount;
    isDepositAndChangeEqual.in[1] <== depositChange;
    isDepositAndChangeEqual.enabled <== isZeroDeposit.out;

    // [1.0] - scale ( a / b = c )
    signal depositScaledAmountTmp <-- depositAmount \ zAssetScale;

    depositScaledAmount <== depositScaledAmountTmp;

    // Audit Bug - 4.1.1 V-PANC-VUL-001: depositScaledAmount is under-constrained
    component rc_depositScaledAmount = LessThan(64);
    rc_depositScaledAmount.in[0] <== depositScaledAmount;
    rc_depositScaledAmount.in[1] <== 2**64;
    rc_depositScaledAmount.out === 1;

    // [1.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a + reminder )
    // depositScaledAmountTmp is RCed via depositScaledAmount, zAssetScale is anchored so its range is known,
    // depositChange forced to 0 by the top component, so, the right expression can't overflow.
    depositAmount === ( depositScaledAmountTmp * zAssetScale ) + depositChange;

    // [1.2] - weighted amount
    depositWeightedScaledAmount <== depositScaledAmountTmp * zAssetWeight;

    component rc_depositWeightedScaledAmount = LessThan(96);
    rc_depositWeightedScaledAmount.in[0] <== depositWeightedScaledAmount;
    rc_depositWeightedScaledAmount.in[1] <== 2**96;
    rc_depositWeightedScaledAmount.out === 1;

    // [1.3] - scaled zZKP donation
    signal addedScaledAmountZkp <-- addedAmountZkp \ zAssetScaleZkp;

    // Audit Bug - 4.1.4 V-PANC-VUL-004: donatedScaledAmountZkp is under-constrained
    component rc_addedScaledAmountZkp = LessThan(96);
    rc_addedScaledAmountZkp.in[0] <== addedScaledAmountZkp;
    rc_addedScaledAmountZkp.in[1] <== 2**96;
    rc_addedScaledAmountZkp.out === 1;

    addedAmountZkp === addedScaledAmountZkp * zAssetScaleZkp;

    // [1.4] - scaled zZKP deposit KYT amount
    component rc_kytDepositChargedAmountZkp = LessThan(96);
    rc_kytDepositChargedAmountZkp.in[0] <== kytDepositChargedAmountZkp;
    rc_kytDepositChargedAmountZkp.in[1] <== 2**96;
    rc_kytDepositChargedAmountZkp.out === 1;

    signal kytDepositScaledChargedAmountZkp <-- kytDepositChargedAmountZkp \ zAssetScaleZkp;

    component rc_kytDepositScaledChargedAmountZkp = LessThan(96);
    rc_kytDepositScaledChargedAmountZkp.in[0] <== kytDepositScaledChargedAmountZkp;
    rc_kytDepositScaledChargedAmountZkp.in[1] <== 2**96;
    rc_kytDepositScaledChargedAmountZkp.out === 1;

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
    signal withdrawScaledAmountTmp <-- withdrawAmount \ zAssetScale;

    withdrawScaledAmount <== withdrawScaledAmountTmp;

    // Audit Bug - 4.1.3 V-PANC-VUL-003: withdrawScaledAmount is under-constrained
    component rc_withdrawScaledAmount = LessThan(64);
    rc_withdrawScaledAmount.in[0] <== withdrawScaledAmount;
    rc_withdrawScaledAmount.in[1] <== 2**64;
    rc_withdrawScaledAmount.out === 1;

    // [2.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a + reminder )
    // withdrawScaledAmountTmp is RCed via withdrawScaledAmount, zAssetScale is anchored so its range is known,
    // withdrawChange forced to 0 by the top component, so, the right expression can't overflow.
    withdrawAmount === ( withdrawScaledAmountTmp * zAssetScale ) + withdrawChange;

    // [2.2] - weighted amount
    withdrawWeightedScaledAmount <== withdrawScaledAmountTmp * zAssetWeight;

    component rc_withdrawWeightedScaledAmount = LessThan(96);
    rc_withdrawWeightedScaledAmount.in[0] <== withdrawWeightedScaledAmount;
    rc_withdrawWeightedScaledAmount.in[1] <== 2**96;
    rc_withdrawWeightedScaledAmount.out === 1;

    // [2.3] - scaled zZKP charge
    signal chargedScaledAmountZkp <-- chargedAmountZkp \ zAssetScaleZkp;

    // Audit Bug - 4.1.6 V-PANC-VUL-006: chargedScaledAmountZkp is under-constrained
    component rc_chargedScaledAmountZkp = LessThan(96);
    rc_chargedScaledAmountZkp.in[0] <== chargedScaledAmountZkp;
    rc_chargedScaledAmountZkp.in[1] <== 2**96;
    rc_chargedScaledAmountZkp.out === 1;

    chargedAmountZkp === chargedScaledAmountZkp * zAssetScaleZkp;

    // [2.4] - scaled zZKP deposit KYT amount
    component rc_kytWithdrawChargedAmountZkp = LessThan(96);
    rc_kytWithdrawChargedAmountZkp.in[0] <== kytWithdrawChargedAmountZkp;
    rc_kytWithdrawChargedAmountZkp.in[1] <== 2**96;
    rc_kytWithdrawChargedAmountZkp.out === 1;

    signal kytWithdrawScaledChargedAmountZkp <-- kytWithdrawChargedAmountZkp \ zAssetScaleZkp;

    component rc_kytWithdrawScaledChargedAmountZkp = LessThan(96);
    rc_kytWithdrawScaledChargedAmountZkp.in[0] <== kytWithdrawScaledChargedAmountZkp;
    rc_kytWithdrawScaledChargedAmountZkp.in[1] <== 2**96;
    rc_kytWithdrawScaledChargedAmountZkp.out === 1;

    kytWithdrawChargedAmountZkp === kytWithdrawScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Withdraw /////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [3] - scaled zZKP internal KYT amount ///////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    component rc_kytInternalChargedAmountZkp = LessThan(96);
    rc_kytInternalChargedAmountZkp.in[0] <== kytInternalChargedAmountZkp;
    rc_kytInternalChargedAmountZkp.in[1] <== 2**96;
    rc_kytInternalChargedAmountZkp.out === 1;

    signal kytInternalScaledChargedAmountZkp <-- kytInternalChargedAmountZkp \ zAssetScaleZkp;

    component rc_kytInternalScaledChargedAmountZkp = LessThan(96);
    rc_kytInternalScaledChargedAmountZkp.in[0] <== kytInternalScaledChargedAmountZkp;
    rc_kytInternalScaledChargedAmountZkp.in[1] <== 2**96;
    rc_kytInternalScaledChargedAmountZkp.out === 1;

    kytInternalChargedAmountZkp === kytInternalScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [4] - Verify total balances /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    signal kytChargedScaledAmountZkp <== kytDepositScaledChargedAmountZkp + kytWithdrawScaledChargedAmountZkp + kytInternalChargedAmountZkp;

    component rc_kytChargedScaledAmountZkpCheck = LessThan(99); // 96 + 3
    rc_kytChargedScaledAmountZkpCheck.in[0] <== kytChargedScaledAmountZkp;
    rc_kytChargedScaledAmountZkpCheck.in[1] <== 2**99;
    rc_kytChargedScaledAmountZkpCheck.out === 1;

    // binary check
    signal rc_isZkpToken <== 0;
    isZkpToken - isZkpToken * isZkpToken === rc_isZkpToken;

    component rc_totalUtxoInAmount = LessThan(70);
    rc_totalUtxoInAmount.in[0] <== totalUtxoInAmount;
    rc_totalUtxoInAmount.in[1] <== 2**70;
    rc_totalUtxoInAmount.out === 1;

    component rc_zAccountUtxoInZkpAmount = LessThan(64);
    rc_zAccountUtxoInZkpAmount.in[0] <== zAccountUtxoInZkpAmount;
    rc_zAccountUtxoInZkpAmount.in[1] <== 2**64;
    rc_zAccountUtxoInZkpAmount.out === 1;

    // depositScaledAmount is RCed, together with zAccountUtxoInZkpAmount & addedScaledAmountZkp, 64 + 64 + 96
    signal totalBalanceIn <== depositScaledAmount + totalUtxoInAmount + isZkpToken * ( zAccountUtxoInZkpAmount + addedScaledAmountZkp );

    component rc_totalUtxoOutAmount = LessThan(70);
    rc_totalUtxoOutAmount.in[0] <== totalUtxoOutAmount;
    rc_totalUtxoOutAmount.in[1] <== 2**70;
    rc_totalUtxoOutAmount.out === 1;

    component rc_zAccountUtxoOutZkpAmount = LessThan(64);
    rc_zAccountUtxoOutZkpAmount.in[0] <== zAccountUtxoOutZkpAmount;
    rc_zAccountUtxoOutZkpAmount.in[1] <== 2**64;
    rc_zAccountUtxoOutZkpAmount.out === 1;

    signal totalBalanceOut <== withdrawScaledAmount + totalUtxoOutAmount + isZkpToken * ( zAccountUtxoOutZkpAmount + chargedScaledAmountZkp + kytChargedScaledAmountZkp );

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
    component lessThen = LessEqThan(64);
    lessThen.in[0] <== zAccountUtxoInZkpAmount;
    lessThen.in[1] <== zAccountUtxoOutZkpAmount;

    // [6.1] -
    // if IN < OUT: choose `zAccountUtxoInZkpAmount`
    // if OUT < IN: choose `zAccountUtxoOutZkpAmount`
    signal mux_input[2];
    mux_input[0] <== lessThen.out * zAccountUtxoInZkpAmount;        // NOT zero if IN =< OUT
    mux_input[1] <== (1 - lessThen.out) * zAccountUtxoOutZkpAmount; // NOT zero if OUT < IN

    // no need to RCed since zAccountUtxo_{In,Out}_ZkpAmounts' are already RCed
    signal zAccountUtxoResidualZkpAmount <== mux_input[0] + mux_input[1];
    // [6.2] - compute total-scaled with respect to zAccount balance in case of zZKP token
    totalScaled <== totalBalanceIn - ( isZkpToken * zAccountUtxoResidualZkpAmount );

    // Audit Bug - 4.1.2 V-PANC-VUL-002: zkpScaledAmount is under-constrained
    component rc_totalScaled = LessThan(96);
    rc_totalScaled.in[0] <== totalScaled;
    rc_totalScaled.in[1] <== 2**96;
    rc_totalScaled.out === 1;

    // [6.3] - compute total-weighted
    totalWeighted <== totalScaled * zAssetWeight;

    component rc_totalWeighted = LessThan(96);
    rc_totalWeighted.in[0] <== totalWeighted;
    rc_totalWeighted.in[1] <== 2**96;
    rc_totalWeighted.out === 1;
}
