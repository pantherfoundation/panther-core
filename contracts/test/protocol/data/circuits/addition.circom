pragma circom 2.0.0;

template Factors() {
    signal input x;
    signal input y;
    signal output z;
    signal i;
    i <-- x + y;
    z <== i;
    z === i;
}

component main = Factors();
