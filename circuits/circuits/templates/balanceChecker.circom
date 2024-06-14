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
    signal input isZkpToken;                        // range-check-tag, assumed to be: 0 - 1
    signal input depositAmount;                     // public-tag, assumed to be: 0 - 2^96
    signal input withdrawAmount;                    // public-tag, assumed to be: 0 - 2^96
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
    signal output depositScaledAmount;              // range-check-tag, assumed to be: 0 - 2^64
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
    assert(0 <= withdrawAmount < 2**96);
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
    // [1.0] - scale ( a / b = c )
    signal depositScaledAmountTmp <-- depositAmount \ zAssetScale;

    depositScaledAmount <== depositScaledAmountTmp;

    // Audit Bug - 4.1.1 V-PANC-VUL-001: depositScaledAmount is under-constrained
    component rc_depositScaledAmount = LessThanBits(64);
    rc_depositScaledAmount.in <== depositScaledAmount;

    // [1.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a )
    // Since depositScaledAmountTmp is RCed via depositScaledAmount, and the range of zAssetScale is
    // fixed (as the signal is anchored), so, the right expression can't overflow.
    depositAmount === ( depositScaledAmountTmp * zAssetScale );

    // [1.2] - weighted amount
    depositWeightedScaledAmount <== depositScaledAmountTmp * zAssetWeight;

    component rc_depositWeightedScaledAmount = LessThanBits(96);
    rc_depositWeightedScaledAmount.in <== depositWeightedScaledAmount;

    // [1.3] - scaled zZKP donation
    signal addedScaledAmountZkp <-- addedAmountZkp \ zAssetScaleZkp;

    // Audit Bug - 4.1.4 V-PANC-VUL-004: donatedScaledAmountZkp is under-constrained
    component rc_addedScaledAmountZkp = LessThanBits(64);
    rc_addedScaledAmountZkp.in <== addedScaledAmountZkp;

    addedAmountZkp === addedScaledAmountZkp * zAssetScaleZkp;

    // [1.4] - scaled zZKP deposit KYT amount
    component rc_kytDepositChargedAmountZkp = LessThanBits(96);
    rc_kytDepositChargedAmountZkp.in <== kytDepositChargedAmountZkp;

    signal kytDepositScaledChargedAmountZkp <-- kytDepositChargedAmountZkp \ zAssetScaleZkp;

    component rc_kytDepositScaledChargedAmountZkp = LessThanBits(96);
    rc_kytDepositScaledChargedAmountZkp.in <== kytDepositScaledChargedAmountZkp;

    kytDepositChargedAmountZkp === kytDepositScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Deposit //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [2] - Withdraw //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [2.0] - scale ( a / b = c )
    signal withdrawScaledAmountTmp <-- withdrawAmount \ zAssetScale;

    withdrawScaledAmount <== withdrawScaledAmountTmp;

    // Audit Bug - 4.1.3 V-PANC-VUL-003: withdrawScaledAmount is under-constrained
    component rc_withdrawScaledAmount = LessThanBits(64);
    rc_withdrawScaledAmount.in <== withdrawScaledAmount;

    // [2.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a )
    // withdrawScaledAmountTmp is RCed via withdrawScaledAmount, zAssetScale is anchored so its range is known,
    // so, the right expression can't overflow.
    withdrawAmount === ( withdrawScaledAmountTmp * zAssetScale );

    // [2.2] - weighted amount
    withdrawWeightedScaledAmount <== withdrawScaledAmountTmp * zAssetWeight;

    component rc_withdrawWeightedScaledAmount = LessThanBits(96);
    rc_withdrawWeightedScaledAmount.in <== withdrawWeightedScaledAmount;

    // [2.3] - scaled zZKP charge
    signal chargedScaledAmountZkp <-- chargedAmountZkp \ zAssetScaleZkp;

    // Audit Bug - 4.1.6 V-PANC-VUL-006: chargedScaledAmountZkp is under-constrained
    component rc_chargedScaledAmountZkp = LessThanBits(96);
    rc_chargedScaledAmountZkp.in <== chargedScaledAmountZkp;

    chargedAmountZkp === chargedScaledAmountZkp * zAssetScaleZkp;

    // [2.4] - scaled zZKP deposit KYT amount
    component rc_kytWithdrawChargedAmountZkp = LessThanBits(96);
    rc_kytWithdrawChargedAmountZkp.in <== kytWithdrawChargedAmountZkp;

    signal kytWithdrawScaledChargedAmountZkp <-- kytWithdrawChargedAmountZkp \ zAssetScaleZkp;

    component rc_kytWithdrawScaledChargedAmountZkp = LessThanBits(96);
    rc_kytWithdrawScaledChargedAmountZkp.in <== kytWithdrawScaledChargedAmountZkp;

    kytWithdrawChargedAmountZkp === kytWithdrawScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Withdraw /////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [3] - scaled zZKP internal KYT amount ///////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    component rc_kytInternalChargedAmountZkp = LessThanBits(96);
    rc_kytInternalChargedAmountZkp.in <== kytInternalChargedAmountZkp;

    signal kytInternalScaledChargedAmountZkp <-- kytInternalChargedAmountZkp \ zAssetScaleZkp;

    component rc_kytInternalScaledChargedAmountZkp = LessThanBits(96);
    rc_kytInternalScaledChargedAmountZkp.in <== kytInternalScaledChargedAmountZkp;

    kytInternalChargedAmountZkp === kytInternalScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [4] - Verify total balances /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    signal kytChargedScaledAmountZkp <== kytDepositScaledChargedAmountZkp + kytWithdrawScaledChargedAmountZkp + kytInternalChargedAmountZkp;

    component rc_kytChargedScaledAmountZkpCheck = LessThanBits(99); // 96 + 3
    rc_kytChargedScaledAmountZkpCheck.in <== kytChargedScaledAmountZkp;

    component rc_isZkpToken = BinaryRangeCheck();
    rc_isZkpToken.in <== isZkpToken;

    component rc_totalUtxoInAmount = LessThanBits(70);
    rc_totalUtxoInAmount.in <== totalUtxoInAmount;

    component rc_zAccountUtxoInZkpAmount = LessThanBits(64);
    rc_zAccountUtxoInZkpAmount.in <== zAccountUtxoInZkpAmount;

    // depositScaledAmount is RCed, together with zAccountUtxoInZkpAmount & addedScaledAmountZkp, 64 + 64 + 96
    signal totalBalanceIn <== depositScaledAmount + totalUtxoInAmount + isZkpToken * ( zAccountUtxoInZkpAmount + addedScaledAmountZkp );

    component rc_totalUtxoOutAmount = LessThanBits(70);
    rc_totalUtxoOutAmount.in <== totalUtxoOutAmount;

    component rc_zAccountUtxoOutZkpAmount = LessThanBits(64);
    rc_zAccountUtxoOutZkpAmount.in <== zAccountUtxoOutZkpAmount;

    signal totalBalanceOut <== withdrawScaledAmount + totalUtxoOutAmount + isZkpToken * ( zAccountUtxoOutZkpAmount + chargedScaledAmountZkp + kytChargedScaledAmountZkp );

    totalBalanceIn === totalBalanceOut;

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
    component rc_totalScaled = LessThanBits(96);
    rc_totalScaled.in <== totalScaled;

    // [6.3] - compute total-weighted
    totalWeighted <== totalScaled * zAssetWeight;

    component rc_totalWeighted = LessThanBits(96);
    rc_totalWeighted.in <== totalWeighted;
}
