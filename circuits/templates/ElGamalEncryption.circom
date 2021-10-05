include "../../node_modules/circomlib/circuits/babyjub.circom"
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/escalarmulany.circom";

template ElGamalEncryption() {
    signal input r; // randomness
    signal input m; // reward points 
    signal input Y[2]; // relayer's public key
    signal output c1[2];
    signal output c2[2];

    component drv_rG = BabyPbk();
    drv_rG.in <== r;
    drv_rG.Ax === c1[0];
    drv_rG.Ay === c1[1];

    component drv_mG = BabyPbk();
    drv_mG.in <== m;

    component n2b = Num2Bits(253);
    n2b.in <== r;

    component drv_rY = EscalarMulAny(253);
    drv_rY.p[0] <== Y[0];
    drv_rY.p[1] <== Y[1];
    for (var i = 0; i < 253; i++) 
      drv_rY.e[i] <== n2b.out[i];

    component drv_mGrY = BabyAdd();
    drv_mGrY.x1 <== drv_mG.Ax;
    drv_mGrY.y1 <== drv_mG.Ay;
    drv_mGrY.x2 <== drv_rY.out[0];
    drv_mGrY.y2 <== drv_rY.out[1];

    c2[0] <== drv_mGrY.xout;
    c2[1] <== drv_mGrY.yout;
}

component main = ElGamalEncryption();