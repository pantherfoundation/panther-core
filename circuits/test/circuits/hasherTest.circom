//SPDX-License-Identifier: ISC
pragma circom 2.0.0;
include "./templates/hasherTester.circom";

// Two private inputs being hashed, public resulted hash
// non-linear constraints: 240, linear constraints: 0
component main {public [hash]} = HasherTester(2);
