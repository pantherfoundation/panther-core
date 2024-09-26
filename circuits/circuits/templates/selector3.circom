//SPDX-License-Identifier: ISC
pragma circom 2.1.9;

 // Switches one of 3 inputs to the output based upon the `sel` signal.
 template Selector3() {
    // Three input signals
    signal input L;
    signal input M;
    signal input R;

    // Selector that chooses the input signal
    signal input sel[2];

    signal output out;

    // Assert sel[i] is 0|1
    assert(sel[0]<=1);
    assert(sel[1]<=1);
    // Enforce sel can't be [1,1]
    0 === sel[0]*sel[1];

    // Considering limitations on `sel` above:
    // | sel[0],sel[1] | inv01 | L*inv01+M*sel[0]+R*sel[1] | Out |
    // |---------------|-------|---------------------------|-----|
    // | 0     ,0      | 1     | L*1    +M*0     +R*0      | L   |
    // | 1     ,0      | 0     | L*0    +M*1     +R*0      | M   |
    // | 0     ,1      | 0     | L*0    +M*0     +R*1      | R   |

    // Intermediary signals
    signal inv0 <== 1-sel[0];
    signal inv1 <== 1-sel[1];
    signal inv01 <== inv0*inv1;
    signal outL <== L*inv01;
    signal outM <== M*sel[0];
    signal outR <== R*sel[1];

    out <== outL + outM + outR;
}
