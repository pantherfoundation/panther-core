//SPDX-License-Identifier: ISC


template LimitChecker() {
    signal input value;

    signal out; // 1 if `value < 2**n_bits`

    var n_bits = 120;

    var limitedValue = 0;
    var weight = 1;

    signal bits[n_bits]; //intermediate signal

    for (var i = 0; i<n_bits; i++) {
        bits[i] <-- (value >> i) & 1;
        bits[i] * (bits[i] - 1 ) === 0;
        limitedValue += bits[i] * weight;
        weight += weight;
    }

    component isEqual = IsEqual();
    isEqual.in[0] <== value;
    isEqual.in[1] <== limitedValue;

    out <== isEqual.out;
}
