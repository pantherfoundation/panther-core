#!/usr/bin/env bash
CIRCOM=circom
SNARKJS=./node_modules/.bin/snarkjs

if [ "$1" ]; then
    CIRCOM=$1
fi

if [ "$2" ]; then
    SNARKJS=$1
fi

circom_compile_v1_extended_step0 () {
    echo "*** circom_compile_addition_step0 ***";
    ${CIRCOM} --r1cs --wasm --sym -o compiled/ circuits/addition.circom;
}

snarkjs_get_ptau_for_phase2 () {
    echo "*** snarkjs_get_ptau_for_phase2 ***";
    if [[ ! -f "powersOfTau28_hez_final_08.ptau" ]]; then
        wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_08.ptau;
    fi
}

snarkjs_r1cs_info_v1_extended_step1 (){
    echo "*** snarkjs_r1cs_info_v1_extended_step1 ***";
    ${SNARKJS} r1cs info compiled/addition.r1cs;
}

snarkjs_export_r1cs_json_step2 () {
    echo "*** snarkjs_export_r1cs_json_step2 ***";
    ${SNARKJS} r1cs export json compiled/addition.r1cs compiled/addition.json
}

snarkjs_pseudo_setup_groth16_step3 () {
    echo "*** snarkjs_pseudo_setup_groth16_step3 ***";
    ${SNARKJS} groth16 setup compiled/addition.r1cs ./powersOfTau28_hez_final_08.ptau compiled/addition_0000.zkey
}

snarkjs_phase2_contribute_1_step4 () {
    echo "*** snarkjs_phase2_contribute_1_step4 ***";
    ${SNARKJS} zkey contribute compiled/addition_0000.zkey compiled/addition_0001.zkey --name="1st Contributor Name" -v
}

snarkjs_phase2_contribute_2_step5 () {
    echo "*** snarkjs_phase2_contribute_2_step5 ***";
    ${SNARKJS} zkey contribute compiled/addition_0001.zkey compiled/addition_0002.zkey --name="2st Contributor Name" -v
}

snarkjs_phase2_contribute_3_step6 () {
    echo "*** snarkjs_phase2_contribute_3_step6 ***";
    ${SNARKJS} zkey contribute compiled/addition_0002.zkey compiled/addition_0003.zkey --name="3st Contributor Name" -v
}

snarkjs_phase2_zkey_verify_step7 () {
    echo "*** snarkjs_phase2_zkey_verify_step7 ***";
    ${SNARKJS} zkey verify compiled/addition.r1cs ./powersOfTau28_hez_final_08.ptau compiled/addition_0003.zkey
}

snarkjs_phase2_apply_random_beacon_step8 () {
    echo "*** snarkjs_phase2_apply_random_beacon_step8 ***";
    ${SNARKJS} zkey beacon compiled/addition_0003.zkey compiled/addition_final.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
}

snarkjs_final_zkey_verify_step9 () {
    echo "*** snarkjs_final_zkey_verify_step9 ***";
    ${SNARKJS} zkey verify compiled/addition.r1cs ./powersOfTau28_hez_final_08.ptau compiled/addition_final.zkey
}

snarkjs_export_verification_key_step10 () {
    echo "*** snarkjs_export_verification_key_step10 ***";
    ${SNARKJS} zkey export verificationkey compiled/addition_final.zkey compiled/addition_verification_key.json
}

snarkjs_create_solidity_verifier_step11 () {
    echo "*** snarkjs_create_solidity_verifier_step11 ***";
    ${SNARKJS} zkey export solidityverifier compiled/addition_final.zkey compiled/addition_final_verifier.sol
}

circom_generate_witness_step12 () {
   echo "*** circom_generate_witness_step12 ***";
       node compiled/addition_js/generate_witness.js compiled/addition_js/addition.wasm input.json compiled/addition_js/witness.wtns

}


circom_create_proof_step13 () {
   echo "*** circom_create_proof_step13 ***";
   ${SNARKJS} groth16 prove compiled/addition_final.zkey  compiled/addition_js/witness.wtns compiled/addition_js/proof.json compiled/addition_js/public.json

}

snark_build_v1_extended () {
    snarkjs_get_ptau_for_phase2 &&
    circom_compile_v1_extended_step0 &&
    snarkjs_r1cs_info_v1_extended_step1 &&
    snarkjs_export_r1cs_json_step2 &&
    snarkjs_pseudo_setup_groth16_step3 &&
#     steps 4-5-6 is production steps - no need for dev-env
    snarkjs_phase2_contribute_1_step4 <<< 'ramdonmess 1' &&
    snarkjs_phase2_contribute_2_step5 <<< 'ramdonmess 2' &&
    snarkjs_phase2_contribute_3_step6 <<< 'ramdonmess 3' &&
    snarkjs_phase2_zkey_verify_step7 &&
    snarkjs_phase2_apply_random_beacon_step8 &&
    snarkjs_final_zkey_verify_step9 &&
    snarkjs_export_verification_key_step10 &&
    snarkjs_create_solidity_verifier_step11 &&
    circom_generate_witness_step12 &&
    circom_create_proof_step13;

}

# MAIN
#snark_build_v1_extended 2>&1 | tee compiled/snark_build_addition.log
#snarkjs_pseudo_setup_groth16_step3 2>&1 | tee compiled/snark_build_addition.log
#circom_generate_witness_step12 2>&1 | tee compiled/snark_build_addition.log
#circom_create_proof_step13 2>&1 | tee compiled/snark_build_addition.log
