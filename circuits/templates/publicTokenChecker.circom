//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/comparators.circom";


template PublicTokenChecker() {
    signal input publicToken;
    signal input tokenAddress;
    signal input extAmounts;

    // `publicToken` must be zero if `extAmounts == 0`, or `tokenAddress` otherwise

    component isZero = IsZero();
    isZero.in <== extAmounts;

    component isEqual = ForceEqualIfEnabled();
    isEqual.in[0] <== publicToken;
    isEqual.in[1] <== tokenAddress;
    isEqual.enabled <== 1-isZero.out;
}
