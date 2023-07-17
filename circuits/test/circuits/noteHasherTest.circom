//SPDX-License-Identifier: ISC
pragma circom 2.1.6;

include "../../circuits/templates/noteHasher.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template TestDesirialized () {
    signal input in;

    component n2b;

    var nBits = 256;
    n2b = Num2Bits(nBits);
    n2b.in <== in;

    // deserialize output "bits" into (single) output signal
    component b2n[2];
    for (var i = 0; i < 2; i++) {
        b2n[i] = Bits2Num(128);
        for (var j = 0; j < 128; j++) {
            if ( i == 0 )
                b2n[i].in[j] <== n2b.out[j];
            if ( i == 1 )
                b2n[i].in[j] <== n2b.out[128+j];
        }
    }
    b2n[0].out === b2n[1].out;
}

template Test() {
    signal input in[2];
    // proof
    in[0] === in[1];
}

template TestOutputCommitment(nUtxoOut) {

    signal input amountsOut[nUtxoOut];
    signal input token;
    signal input createTime;
    signal input spendPubKeys[nUtxoOut][2];
    // public - Poseidon(5) hash of spendPubKeys, amountOut, token, createTime
    signal input commitmentsOut[nUtxoOut];


    component outputNoteHashers[nUtxoOut];

    for(var i = 0; i < nUtxoOut; i++) {
        outputNoteHashers[i] = NoteHasher();
        outputNoteHashers[i].spendPk[0] <== spendPubKeys[i][0];
        outputNoteHashers[i].spendPk[1] <== spendPubKeys[i][1];
        outputNoteHashers[i].amount <== amountsOut[i];
        outputNoteHashers[i].token <== token;
        outputNoteHashers[i].createTime <== createTime;
        //log(spendPubKeys[i][0]);
        //log(spendPubKeys[i][1]);
        //log(amountsOut[i]);
        //log(token);
        //log(createTime);
        //log(commitmentsOut[i]);
        //log(outputNoteHashers[i].out);
        outputNoteHashers[i].out === commitmentsOut[i];
    }
    // Static hashes verification - mirroring same code in keychain.test.ts
    component hasher = Poseidon(5);
    hasher.inputs[0] <== 18387562449515087847139054493296768033506512818644357279697022045358977016147;
    hasher.inputs[1] <== 2792662591747231738854329419102915533513463924144922287150280827153219249810;
    hasher.inputs[2] <== 7;
    hasher.inputs[3] <== 111;
    hasher.inputs[4] <== 1651062006;
    //log(hasher.out);
    hasher.out === 5001742625244953632730801981278686902609014698786426456727933168831153597234;

    component hasher1 = Poseidon(5);
    hasher1.inputs[0] <== 0;
    hasher1.inputs[1] <== 0;
    hasher1.inputs[2] <== 7;
    hasher1.inputs[3] <== 111;
    hasher1.inputs[4] <== 1651062006;
    //log(hasher1.out);
    hasher1.out === 18335068061156621548650889944271694005071810335442067112588634337332974771015;

    component hasher2 = Poseidon(5);
    hasher2.inputs[0] <== 255;
    hasher2.inputs[1] <== 255;
    hasher2.inputs[2] <== 255;
    hasher2.inputs[3] <== 255;
    hasher2.inputs[4] <== 255;
    //log(hasher2.out);
    hasher2.out === 9158469382714272679214567171722446832175834184106826938670734270762622595936;

    var SNARK_FIELD_R = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    component hasher3 = Poseidon(5);
    hasher3.inputs[0] <== SNARK_FIELD_R-255;
    hasher3.inputs[1] <== SNARK_FIELD_R-255;
    hasher3.inputs[2] <== SNARK_FIELD_R-255;
    hasher3.inputs[3] <== SNARK_FIELD_R-255;
    hasher3.inputs[4] <== SNARK_FIELD_R-255;
    //log(hasher3.out);
    hasher3.out === 9284703829101401842806305250296207491824175622648144921747728478914660578915;

    component hasher4 = Poseidon(5);
    hasher4.inputs[0] <== SNARK_FIELD_R-254;
    hasher4.inputs[1] <== SNARK_FIELD_R-254;
    hasher4.inputs[2] <== SNARK_FIELD_R-254;
    hasher4.inputs[3] <== SNARK_FIELD_R-254;
    hasher4.inputs[4] <== SNARK_FIELD_R-254;
    //log(hasher4.out);
    hasher4.out === 9279502466670636618923158974600161429695759152475836773780046493018792579393;

    component hasher5 = Poseidon(5);
    hasher5.inputs[0] <== SNARK_FIELD_R-1;
    hasher5.inputs[1] <== SNARK_FIELD_R-1;
    hasher5.inputs[2] <== SNARK_FIELD_R-1;
    hasher5.inputs[3] <== SNARK_FIELD_R-1;
    hasher5.inputs[4] <== SNARK_FIELD_R-1;
    //log(hasher5.out);
    hasher5.out === 14245385636416310751802326058548440958818944099491829547963012562257855165452;

    var DELTA = SNARK_FIELD_R - 18387562449515087847139054493296768033506512818644357279697022045358977016147;
    component hasher6 = Poseidon(5);
    hasher6.inputs[0] <== 18387562449515087847139054493296768033506512818644357279697022045358977016147;
    hasher6.inputs[1] <== 18387562449515087847139054493296768033506512818644357279697022045358977016147;
    hasher6.inputs[2] <== 18387562449515087847139054493296768033506512818644357279697022045358977016147;
    hasher6.inputs[3] <== 18387562449515087847139054493296768033506512818644357279697022045358977016147;
    hasher6.inputs[4] <== 18387562449515087847139054493296768033506512818644357279697022045358977016147;
    //log(hasher6.out);
    hasher6.out === 16767453347033023360109575202027130152602306111164087698383102184692354394187;

    component hasher7 = Poseidon(5);
    hasher7.inputs[0] <== SNARK_FIELD_R - (DELTA-5);
    hasher7.inputs[1] <== SNARK_FIELD_R - (DELTA-5);
    hasher7.inputs[2] <== SNARK_FIELD_R - (DELTA-5);
    hasher7.inputs[3] <== SNARK_FIELD_R - (DELTA-5);
    hasher7.inputs[4] <== SNARK_FIELD_R - (DELTA-5);
    //log(hasher7.out);
    hasher7.out === 13283573424985425594789753755317679868118676726585778740895243807393964890264;

    component hasher8 = Poseidon(5);
    hasher8.inputs[0] <== SNARK_FIELD_R - (DELTA+5);
    hasher8.inputs[1] <== SNARK_FIELD_R - (DELTA+5);
    hasher8.inputs[2] <== SNARK_FIELD_R - (DELTA+5);
    hasher8.inputs[3] <== SNARK_FIELD_R - (DELTA+5);
    hasher8.inputs[4] <== SNARK_FIELD_R - (DELTA+5);
    //log(hasher8.out);
    hasher8.out === 18537804025757946212552451232719218634779181519233353091102034383213424240767;
}

template TestOutputCommitment2() {

    signal input amountsOut;
    signal input token;
    signal input createTime;
    signal input spendPubKeys;
    signal input commitmentsOut; // public - Poseidon(4) hash of spendPubKeys, amountOut, token, createTime


    component noteHasher = Poseidon(4);

    noteHasher.inputs[0] <== amountsOut;
    noteHasher.inputs[1] <== token;
    noteHasher.inputs[2] <== createTime;
    noteHasher.inputs[3] <== spendPubKeys;

    log(noteHasher.out);
    log(commitmentsOut);
    noteHasher.out === commitmentsOut;
}

// component main {public [in]} = TestDesirialized();
// component main {public [in]} = Test();
component main {public [commitmentsOut]} = TestOutputCommitment(3);
