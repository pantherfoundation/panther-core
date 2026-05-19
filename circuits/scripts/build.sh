#!/usr/bin/env bash
CIRCOM=circom
SNARKJS=./node_modules/.bin/snarkjs

if [ "$1" ]; then
    CIRCOM=$1
fi

if [ "$2" ]; then
    SNARKJS=$2
fi

snarkjs_get_ptau_for_phase2 () {
    echo "*** snarkjs_get_ptau ***";
    if [[ ! -f "powersOfTau28_hez_final_18.ptau" ]]; then
        wget https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_18.ptau;
    fi
}

circom_compile_v1_extended_step0 () {
    echo "*** $1: circom_compile_v1_extended_step0 ***";
    ${CIRCOM} --r1cs --wasm --sym -o compiled/ circuits/$1.circom;
}


snarkjs_r1cs_info_v1_extended_step1 (){
    echo "*** $1: snarkjs_r1cs_info_v1_extended_step1 ***";
    ${SNARKJS} r1cs info compiled/$1.r1cs;
}

snarkjs_export_r1cs_json_step2 () {
    echo "*** $1: snarkjs_export_r1cs_json_step2 ***";
    ${SNARKJS} r1cs export json compiled/$1.r1cs compiled/$1.json
}

snarkjs_pseudo_setup_groth16_step3 () {
    echo "*** $1: snarkjs_pseudo_setup_groth16_step3 ***";
    ${SNARKJS} groth16 setup compiled/$1.r1cs ./powersOfTau28_hez_final_18.ptau compiled/$1.zkey
}

build_circuit() {
   echo "circuit_$1"
   circom_compile_v1_extended_step0 $1 &&
   snarkjs_r1cs_info_v1_extended_step1 $1 &&
   snarkjs_export_r1cs_json_step2 $1 &&
   snarkjs_pseudo_setup_groth16_step3 $1;
}

build () {
    snarkjs_get_ptau_for_phase2;

    build_circuit mainZTransactionV1
    build_circuit mainTreeBatchUpdaterAndRootChecker
    build_circuit mainZAccountRegistrationV1
    build_circuit mainZAccountRenewalV1
    build_circuit mainZSwapV1
}

# MAIN
build 2>&1 | tee compiled/build.log
