//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";

template TrustProvidersMerkleTreeLeafIDAndRuleInclusionProver(){
    signal input enabled;
    signal input {uint16}  leafId;                // 16 bit
    signal input {uint8}   rule;                  // 8 bit
    signal input {uint240} leafIDsAndRulesList;   // 240 bit
    signal input {uint4}   offset;                // 4 bit

    assert(leafIDsAndRulesList < 2**240);
    assert(offset < 10);
    component offset_lessThan_10 = LessThan(4);
    offset_lessThan_10.in[0] <== offset;
    offset_lessThan_10.in[1] <== 10;

    component n2b_leafIDsAndRulesList = Num2Bits(10 * 24);
    n2b_leafIDsAndRulesList.in <== leafIDsAndRulesList;

    component selector[10];
    component b2n_leafIdAndRulesList[10];
    component multiSum_leafIDAndRule = MultiSum(10);

    for(var i = 0; i < 10; i++) {
        selector[i] = IsEqual();
        selector[i].in[0] <== i;
        selector[i].in[1] <== offset;

        b2n_leafIdAndRulesList[i] = Bits2Num(24);

        for(var j = 0; j < 24; j++) {
            b2n_leafIdAndRulesList[i].in[j] <== n2b_leafIDsAndRulesList.out[24 * i + j];
        }
        // selector is one only for specific place (0..9)
        multiSum_leafIDAndRule.in[i] <== selector[i].out * b2n_leafIdAndRulesList[i].out;
    }
    // since only one of 0..9 is not zero -> the rolling sum works as mux
    component n2b = Num2Bits(24);
    n2b.in <== multiSum_leafIDAndRule.out;

    component b2nRule = Bits2Num(8);
    for (var i = 0; i < 8; i++) {
        b2nRule.in[i] <== n2b.out[i];
    }

    component isEqualRule = ForceEqualIfEnabled();
    isEqualRule.in[0] <== rule;
    isEqualRule.in[1] <== b2nRule.out;
    isEqualRule.enabled <== enabled;

    component b2nLeafId = Bits2Num(16);
    for (var i = 8; i < 24; i++) {
        b2nLeafId.in[i-8] <== n2b.out[i];
    }

    component isEqualLeafId = ForceEqualIfEnabled();
    isEqualLeafId.in[0] <== leafId;
    isEqualLeafId.in[1] <== b2nLeafId.out;
    isEqualLeafId.enabled <== enabled;

}

template MultiSum(n) {
    signal input in[n];
    signal output out;
    assert(n > 0);

    component sums[2];
    if ( n == 1 ) {
        out <== in[0];
    } else if ( n == 2 ) {
        out <== in[0] + in[1];
    } else {
        var n1 = n\2;
        var n2 = n-n\2;
        sums[0] = MultiSum(n1);
        sums[1] = MultiSum(n2);
        for (var i = 0; i < n1; i++) {
            sums[0].in[i] <== in[i];
        }
        for (var i = 0; i < n2; i++)  {
            sums[1].in[i] <== in[n1+i];
        }
        out <== sums[0].out + sums[1].out;
    }
}
