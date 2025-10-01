#!/usr/bin/env bash
CIRCOM=circom
SNARKJS=./node_modules/.bin/snarkjs

if [ "$1" ]; then
    CIRCOM=$1
fi

if [ "$2" ]; then
    SNARKJS=$2
fi

circom_compile_v1_extended_step0 () {
    echo "*** circom_compile_v1_extended_step0 ***";
    ${CIRCOM} --r1cs --wasm --sym -o compiled/ circuits/mainZTransactionV1.circom;
}

# since the circuit is bigger than 2**17 we are moving to the next big ptau file.
snarkjs_get_ptau_for_phase2 () {
    echo "*** snarkjs_get_ptau_for_phase2 ***";
    if [[ ! -f "powersOfTau28_hez_final_18.ptau" ]]; then
        wget https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_18.ptau;
    fi
}

snarkjs_r1cs_info_v1_extended_step1 (){
    echo "*** snarkjs_r1cs_info_v1_extended_step1 ***";
    ${SNARKJS} r1cs info compiled/mainZTransactionV1.r1cs;
}

snarkjs_export_r1cs_json_step2 () {
    echo "*** snarkjs_export_r1cs_json_step2 ***";
    ${SNARKJS} r1cs export json compiled/mainZTransactionV1.r1cs compiled/mainTransaction_v1_extended.json
}

snarkjs_pseudo_setup_groth16_step3 () {
    echo "*** snarkjs_pseudo_setup_groth16_step3 ***";
    ${SNARKJS} groth16 setup compiled/mainZTransactionV1.r1cs ./powersOfTau28_hez_final_18.ptau compiled/mainTransaction_v1_extended_0000.zkey
}

snarkjs_phase2_contribute_1_step4 () {
    echo "*** snarkjs_phase2_contribute_1_step4 ***";
    ${SNARKJS} zkey contribute compiled/mainTransaction_v1_extended_0000.zkey compiled/mainTransaction_v1_extended_0001.zkey --name="1st Contributor Name" -v
}

snarkjs_phase2_contribute_2_step5 () {
    echo "*** snarkjs_phase2_contribute_2_step5 ***";
    ${SNARKJS} zkey contribute compiled/mainTransaction_v1_extended_0001.zkey compiled/mainTransaction_v1_extended_0002.zkey --name="2st Contributor Name" -v
}

snarkjs_phase2_contribute_3_step6 () {
    echo "*** snarkjs_phase2_contribute_3_step6 ***";
    ${SNARKJS} zkey contribute compiled/mainTransaction_v1_extended_0002.zkey compiled/mainTransaction_v1_extended_0003.zkey --name="3st Contributor Name" -v
}

snarkjs_phase2_zkey_verify_step7 () {
    echo "*** snarkjs_phase2_zkey_verify_step7 ***";
    ${SNARKJS} zkey verify compiled/mainZTransactionV1.r1cs ./powersOfTau28_hez_final_18.ptau compiled/mainTransaction_v1_extended_0003.zkey
}

snarkjs_phase2_apply_random_beacon_step8 () {
    echo "*** snarkjs_phase2_apply_random_beacon_step8 ***";
    ${SNARKJS} zkey beacon compiled/mainTransaction_v1_extended_0003.zkey compiled/mainTransaction_v1_extended_final.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
}

snarkjs_final_zkey_verify_step9 () {
    echo "*** snarkjs_final_zkey_verify_step9 ***";
    ${SNARKJS} zkey verify compiled/mainZTransactionV1.r1cs ./powersOfTau28_hez_final_18.ptau compiled/mainTransaction_v1_extended_final.zkey
}

snarkjs_export_verification_key_step10 () {
    echo "*** snarkjs_export_verification_key_step10 ***";
    ${SNARKJS} zkey export verificationkey compiled/mainTransaction_v1_extended_final.zkey compiled/mainTransaction_v1_extended_verification_key.json
}

snarkjs_create_solidity_verifier_step11 () {
    echo "*** snarkjs_create_solidity_verifier_step11 ***";
    ${SNARKJS} zkey export solidityverifier compiled/mainTransaction_v1_extended_final.zkey compiled/mainTransaction_v1_extended_final_verifier.sol
}

export_final_artifacts_step12 () {
    echo "*** export_final_artifacts_step12 ***";
    mkdir -p compiled/zTransaction &&
    mv compiled/mainZTransactionV1.r1cs compiled/zTransaction/circuits.r1cs &&
    mv compiled/mainZTransactionV1_js/mainZTransactionV1.wasm compiled/zTransaction/circuits.wasm &&
    mv compiled/mainTransaction_v1_extended_final.zkey compiled/zTransaction/provingKey.zkey &&
    mv compiled/mainTransaction_v1_extended_verification_key.json compiled/zTransaction/verificationKey.json &&
    mv compiled/mainTransaction_v1_extended_final_verifier.sol compiled/zTransaction/verifier.sol
}

cleanup_intermediate_artifacts_step13 () {
    echo "*** cleanup_intermediate_artifacts_step13 ***";
    rm -f compiled/mainTransaction_v1_extended_0000.zkey compiled/mainTransaction_v1_extended_0001.zkey compiled/mainTransaction_v1_extended_0002.zkey compiled/mainTransaction_v1_extended_0003.zkey compiled/mainZTransactionV1.r1cs compiled/mainZTransactionV1.sym compiled/mainTransaction_v1_extended.json compiled/mainTransaction_v1_extended_final.zkey compiled/mainTransaction_v1_extended_verification_key.json compiled/mainTransaction_v1_extended_final_verifier.sol compiled/snark_build_v1_extended.log;
    rm -rf compiled/mainZTransactionV1_js
}

snark_build_v1_extended () {
    snarkjs_get_ptau_for_phase2 &&
    circom_compile_v1_extended_step0 &&
    snarkjs_r1cs_info_v1_extended_step1 &&
    snarkjs_export_r1cs_json_step2 &&
    snarkjs_pseudo_setup_groth16_step3 &&
    # steps 4-5-6 is production steps - no need for dev-env
    snarkjs_phase2_contribute_1_step4 <<< 'ramdonmess 1' &&
    snarkjs_phase2_contribute_2_step5 <<< 'ramdonmess 2' &&
    snarkjs_phase2_contribute_3_step6 <<< 'ramdonmess 3' &&
    snarkjs_phase2_zkey_verify_step7 &&
    snarkjs_phase2_apply_random_beacon_step8 &&
    snarkjs_final_zkey_verify_step9 &&
    snarkjs_export_verification_key_step10 &&
    snarkjs_create_solidity_verifier_step11 &&
    export_final_artifacts_step12 &&
    cleanup_intermediate_artifacts_step13;
}

# MAIN
snark_build_v1_extended 2>&1 | tee compiled/snark_build_v1_extended.log
