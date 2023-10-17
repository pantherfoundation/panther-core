#!/bin/bash
CIRCOM_EXE=~/.cargo/bin/circom

CIRCUIT_NAME=$1
INPUT_JSON=$2

if [ "$3" ]; then
    CIRCOM_EXE=$3
fi

CIRCUIT_BASE_NAME=$(echo ${CIRCUIT_NAME} | sed "s/\.circom//g")

${CIRCOM_EXE} ${CIRCUIT_NAME} --r1cs --wasm --sym --verbose --c

cd ${CIRCUIT_BASE_NAME}_js

set RESULT="UNDIFINED"

# directory - NOTE: its relative path
json_arr=(../${INPUT_JSON}/*)
json_arr_len=${#json_arr[@]}

NUMBER_OF_THREADS=16
p=$(expr $json_arr_len / $NUMBER_OF_THREADS)

echo 0 >> JN
run_parallel_loop() {
    jn=$(cat JN)
    jn=$(expr $jn + 1)
    echo $jn > JN

    arr=($@)
    for json in "${arr[@]}"; do
        name=$(echo $json | awk -F "/" '{print $NF}')
        node generate_witness.js ${CIRCUIT_BASE_NAME}.wasm ${json} witness_${name}.wtns
        if [ -f "witness_${name}.wtns" ]; then
            echo "***************** TEST ${CIRCUIT_NAME} ${json} SUCCESS ******************** JOB:${jn}"
            RESULT=0
            rm -f witness_${json}.wtns
        else
            echo "Execution of $name ---- $json --- witness_${name}.wtns FAILED"
            echo "TEST ${CIRCUIT_NAME} ${json} FAIL"
            RESULT=1
        fi
    done
}

for ((i = 0; i < ${json_arr_len}; i = i + ${p})); do
    d=$((${i} + ${p}))
    if ((${d} < ${json_arr_len})); then
        run_parallel_loop ${json_arr[@]:${i}:${p}} &
    else
        dd=$(("$json_arr_len" - "$i"))
        run_parallel_loop ${json_arr[@]:${i}:${dd}} &
    fi
done

wait < <(jobs -p)

rm -f JN

cd ../

rm -rf ${CIRCUIT_BASE_NAME}_js
rm -rf ${CIRCUIT_BASE_NAME}_cpp
rm -rf ${CIRCUIT_BASE_NAME}.r1cs
rm -rf ${CIRCUIT_BASE_NAME}.sym

return ${RESULT}
