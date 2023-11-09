//SPDX-License-Identifier: ISC
pragma circom 2.1.6;
include "./templates/rangeCheck.circom";

component main {public [in]} = RangeCheck(256,251);
