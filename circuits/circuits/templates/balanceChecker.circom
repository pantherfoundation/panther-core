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
    signal input {binary}          isZkpToken;
    signal input {uint96}          depositAmount;
    signal input {uint96}          withdrawAmount;
    signal input {uint96}          chargedAmountZkp;
    signal input {uint96}          addedAmountZkp;
    signal input {uint64}          zAccountUtxoInZkpAmount;
    signal input {uint64}          zAccountUtxoOutZkpAmount;
    signal input {uint70}          totalUtxoInAmount;
    signal input {uint70}          totalUtxoOutAmount;
    signal input {non_zero_uint32} zAssetWeight;
    signal input {non_zero_uint64} zAssetScale;
    signal input {non_zero_uint64} zAssetScaleZkp;
    signal input {uint96}          kytDepositChargedAmountZkp;
    signal input {uint96}          kytWithdrawChargedAmountZkp;
    signal input {uint96}          kytInternalChargedAmountZkp;
    signal output {uint64}         depositScaledAmount;
    signal output {uint96}         depositWeightedScaledAmount;
    signal output {uint64}         withdrawScaledAmount;
    signal output {uint96}         withdrawWeightedScaledAmount;
    signal output {uint96}         totalScaled;
    signal output {uint96}         totalWeighted;
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

    var ACTIVE = Active();
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [1] - Deposit ///////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [1.0] - scale ( a / b = c )
    signal depositScaledAmountTmp <-- depositAmount \ zAssetScale;

    // Audit Bug - 4.1.1 V-PANC-VUL-001: depositScaledAmount is under-constrained
    depositScaledAmount <== Uint64Tag(ACTIVE)(depositScaledAmountTmp);

    // [1.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a )
    // Since depositScaledAmountTmp is RCed via depositScaledAmount, and the range of zAssetScale is
    // fixed (as the signal is anchored), so, the right expression can't overflow.
    depositAmount === ( depositScaledAmount * zAssetScale );

    // [1.2] - weighted amount
    depositWeightedScaledAmount <== Uint96Tag(ACTIVE)( depositScaledAmount * zAssetWeight );

    // [1.3] - scaled zZKP donation
    signal addedScaledAmountZkp <-- addedAmountZkp \ zAssetScaleZkp;

    // Audit Bug - 4.1.4 V-PANC-VUL-004: donatedScaledAmountZkp is under-constrained
    signal addedScaledAmountZkpTmp <== Uint64Tag(ACTIVE)(addedScaledAmountZkp);

    addedAmountZkp === addedScaledAmountZkpTmp * zAssetScaleZkp;

    // [1.4] - scaled zZKP deposit KYT amount
    signal kytDepositScaledChargedAmountZkpTmp <-- kytDepositChargedAmountZkp \ zAssetScaleZkp;

    signal kytDepositScaledChargedAmountZkp <== Uint96Tag(ACTIVE)(kytDepositScaledChargedAmountZkpTmp);

    kytDepositChargedAmountZkp === kytDepositScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Deposit //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [2] - Withdraw //////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [2.0] - scale ( a / b = c )
    signal withdrawScaledAmountTmp <-- withdrawAmount \ zAssetScale;

    // Audit Bug - 4.1.3 V-PANC-VUL-003: withdrawScaledAmount is under-constrained
    withdrawScaledAmount <== Uint64Tag(ACTIVE)(withdrawScaledAmountTmp);

    // [2.1] - restore ( a / b = c --> c * b = a ) & constrain ( c * b === a )
    // withdrawScaledAmountTmp is RCed via withdrawScaledAmount, zAssetScale is anchored so its range is known,
    // so, the right expression can't overflow.
    withdrawAmount === ( withdrawScaledAmount * zAssetScale );

    // [2.2] - weighted amount
    withdrawWeightedScaledAmount <== Uint96Tag(ACTIVE)(withdrawScaledAmount * zAssetWeight);

    // [2.3] - scaled zZKP charge
    signal chargedScaledAmountZkpTmp <-- chargedAmountZkp \ zAssetScaleZkp;

    // Audit Bug - 4.1.6 V-PANC-VUL-006: chargedScaledAmountZkp is under-constrained
    signal chargedScaledAmountZkp <== Uint96Tag(ACTIVE)(chargedScaledAmountZkpTmp);

    chargedAmountZkp === chargedScaledAmountZkp * zAssetScaleZkp;

    // [2.4] - scaled zZKP deposit KYT amount
    signal kytWithdrawScaledChargedAmountZkpTmp <-- kytWithdrawChargedAmountZkp \ zAssetScaleZkp;

    signal kytWithdrawScaledChargedAmountZkp <== Uint96Tag(ACTIVE)(kytWithdrawScaledChargedAmountZkpTmp);

    kytWithdrawChargedAmountZkp === kytWithdrawScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // End of Withdraw /////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [3] - scaled zZKP internal KYT amount ///////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    signal kytInternalScaledChargedAmountZkpTmp <-- kytInternalChargedAmountZkp \ zAssetScaleZkp;

    signal kytInternalScaledChargedAmountZkp <== Uint96Tag(ACTIVE)(kytInternalScaledChargedAmountZkpTmp);

    kytInternalChargedAmountZkp === kytInternalScaledChargedAmountZkp * zAssetScaleZkp;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // [4] - Verify total balances /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    signal kytChargedScaledAmountZkp <== UintTag(ACTIVE,99)(kytDepositScaledChargedAmountZkp + kytWithdrawScaledChargedAmountZkp + kytInternalChargedAmountZkp); // 96 + 3

    // depositScaledAmount is RCed, together with zAccountUtxoInZkpAmount & addedScaledAmountZkp, 64 + 64 + 96
    signal totalBalanceIn <== depositScaledAmount + totalUtxoInAmount + isZkpToken * ( zAccountUtxoInZkpAmount + addedScaledAmountZkp );

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
    // Audit Bug - 4.1.2 V-PANC-VUL-002: zkpScaledAmount is under-constrained
    totalScaled <== Uint96Tag(ACTIVE)(totalBalanceIn - ( isZkpToken * zAccountUtxoResidualZkpAmount ));

    // [6.3] - compute total-weighted
    totalWeighted <== Uint96Tag(ACTIVE)(totalScaled * zAssetWeight);
}
