import fs from 'fs';
import path from 'path';

type G1PointStruct = {x: string; y: string};
type G2PointStruct = {
    x: [string, string];
    y: [string, string];
};
type SnarkProofStruct = {
    a: G1PointStruct;
    b: G2PointStruct;
    c: G1PointStruct;
};

type JsonProof = {
    pi_a: string[];
    pi_b: string[][];
    pi_c: string[];
    protocol?: string;
    curve?: string;
};

function getJsonPaths(circuitName: string) {
    const inputsPath = path.resolve(
        __dirname,
        '..',
        'data',
        `${circuitName}_public.json`,
    );

    const proofPath = path.resolve(
        __dirname,
        '..',
        'data',
        `${circuitName}_proof.json`,
    );

    return {inputsPath, proofPath};
}

function getJsonData(circuitName: string) {
    const {inputsPath, proofPath} = getJsonPaths(circuitName);

    const inputsData = JSON.parse(
        fs.readFileSync(inputsPath).toString(),
    ) as string[];

    const proofData = JSON.parse(
        fs.readFileSync(proofPath).toString(),
    ) as JsonProof;

    return {inputsData, proofData};
}

function getProofAndInputs(circuitName: string) {
    const {inputsData: inputs, proofData} = getJsonData(circuitName);
    const {pi_a, pi_b, pi_c} = proofData;

    const proof: SnarkProofStruct = {
        a: {x: pi_a[0], y: pi_a[1]},
        b: {
            x: [pi_b[0][1], pi_b[0][0]],
            y: [pi_b[1][1], pi_b[1][0]],
        },
        c: {x: pi_c[0], y: pi_c[1]},
    };

    return {proof, inputs};
}

export {getProofAndInputs};
