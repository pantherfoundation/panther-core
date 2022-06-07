#!/bin/bash 
CIRCOM_EXE=~/.cargo/bin/circom 

CIRCUIT_NAME=$1 
INPUT_JSON=$2

if [ "$3"]; then
    CIRCOM_EXE=$3
fi 

CIRCUIT_BASE_NAME=`echo ${CIRCUIT_NAME} | sed "s/\.circom//g"`;

${CIRCOM_EXE} ${CIRCUIT_NAME} --r1cs --wasm --sym --verbose --c

cd ${CIRCUIT_BASE_NAME}_js

node generate_witness.js ${CIRCUIT_BASE_NAME}.wasm ../${INPUT_JSON} witness.wtns

RESULT="UNDIFINED"
if [ -f "witness.wtns" ]; then
    echo "***************** TEST ${CIRCUIT_NAME} ${INPUT_JSON} SUCCESS ********************"
    RESULT=0
else
    echo "TEST ${CIRCUIT_NAME} ${INPUT_JSON} FAIL"
    RESULT=1
fi

cd ../

rm -rf ${CIRCUIT_BASE_NAME}_js
rm -rf ${CIRCUIT_BASE_NAME}_cpp
rm -rf ${CIRCUIT_BASE_NAME}.r1cs
rm -rf ${CIRCUIT_BASE_NAME}.sym

return ${RESULT}

