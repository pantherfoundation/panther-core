//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/gates.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";

template TrustProvidersMerkleTreeLeafIDAndRuleInclusionProver(){
    signal input enabled;
    signal input leafId;                // 16 bit
    signal input rule;                  // 8 bit
    signal input leafIDsAndRulesList;   // 256 bit
    signal input offset;                // 4 bit

    assert(offset < 10);
    var ellement_offset = offset * 24;
    component n2b = Num2Bits(24);
    signal temp;
    temp <-- leafIDsAndRulesList >> ellement_offset;
    n2b.in <== temp;

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
