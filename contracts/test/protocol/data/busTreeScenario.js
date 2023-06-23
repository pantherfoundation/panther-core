#!/usr/bin/node
/**
 * @dev This script (deterministically) generates data fot the test scenario
 * and writes the scenario to the file `__dirname/busTreeScenario.json`.
 */

/* eslint @typescript-eslint/no-var-requires: 0 */
const assert = require('assert');
const {readFileSync, writeFileSync} = require('fs');
const {join} = require('path');

const {poseidon} = require('circomlibjs');
const ethers = require('ethers');

// The number of Queues (Batches) to generate for the test
// (extension of `scenarioSteps` needed, if it's exceed 32)
const nBatches = 32;
console.info(`Generating scenario with ${nBatches} Batches`);

/**** 0. Let's define some helpers and constants ***/
const numToBytes32 = n => ethers.utils.hexZeroPad('0x' + n.toString(16), 32);
const oneInputHash = n => numToBytes32(poseidon([n]));
const twoInputHash = (a, b) => numToBytes32(poseidon([a, b]));

// Value in an "empty" leaf
const emptyLeaf =
    '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d';
// Root of the Bus Tree with empty leafs only (i.e. before insertions)
const emptyBusTreeRoot =
    '0x1bdded415724018275c7fcc2f564f64db01b5bbeb06d65700564b05c3c59c9e6';
// Root of a Bus Tree's branch with empty leafs only
const emptyBranchRoot =
    '0xa5e5ec37bd8f9a21a1c2192e7c37d86bf975d947c2b38598b00babe567191c9';
// Root of a Batch from empty leafs only
const emptyBatch =
    '0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69';

// Empty node roots, one per level, from Batch roots upto the Branch root
const getEmptyNodeAtGivenNumLevelsAboveBatchRoots = numLevelsAbove =>
    [
        emptyBatch,
        '0x225624653ac89fe211c0c3d303142a4caf24eb09050be08c33af2e7a1e372a0f',
        '0x276c76358db8af465e2073e4b25d6b1d83f0b9b077f8bd694deefe917e2028d7',
        '0x09df92f4ade78ea54b243914f93c2da33414c22328a73274b885f32aa9dea718',
        '0x1c78b565f2bfc03e230e0cf12ecc9613ab8221f607d6f6bc2a583ccd690ecc58',
        '0x2879d62c83d6a3af05c57a4aee11611a03edec5ff8860b07de77968f47ff1c5f',
        '0x28ad970560de01e93b613aabc930fcaf087114743909783e3770a1ed07c2cde6',
        '0x27ca60def9dd0603074444029cbcbeaa9dbe77668479ac1db738bb892d9f3b6d',
        '0x28e4c1e90bbfa69de93abf6cbdc7cd1c0753a128e83b2b3afe34e0471a13ff55',
        '0x1b89c44a9f153266ad5bf754d4b252c26acba7d21fc661b94dc0618c6a82f49c',
        emptyBranchRoot,
    ][numLevelsAbove];

// Empty node roots, one per level, from Branch roots upto the Bus Tree root
const getEmptyNodeAtGivenNumLevelsAboveBranchRoots = numLevelsAbove =>
    [
        emptyBranchRoot,
        '0x21fb04b171b68944c640020a3a464602ec8d02495c44f1e403d9be4a97128e49',
        '0x19151c748859974805eb30feac7a301266dec9f67e23e285fe750f86448a2af9',
        '0x18fb0b755218eaa809681eb87e45925faa9197507d368210d73b5836ebf139e4',
        '0x1e294375b42dfd97795e07e1fe8bd6cefcb16c3bbb71b30bed950f8965861244',
        '0x0d3e4235db275d9bab0808dd9ade8789d46d0e1f1c9a99ce73fefca51dc92f4a',
        '0x075ab2ca945c4dc5ea40a9f1c66d5bf3c367cef1e04e73aa17c2bc747eb5fc87',
        '0x26f0f533a8ea2210001aeb8f8306c7c70656ba6afe145c6540bd4ed2c967a230',
        '0x24be7e64f680326e6e3621e5862d7b6b1f31e9e183a0bf5dd04e823be84e6af9',
        '0x212b13c9cbf421942ae3e3c62a3c072903c2a745a220cfb3c43cd520f55f44bf',
        emptyBusTreeRoot,
    ][numLevelsAbove];

/**** 1. Generate Queues and Batches from them ***/

function generateBatchData(queueId) {
    // Generate pseudo-random number in [32..64], with probability density peak at 64,
    // to be a number of non-empty UTXOs in a queue
    const nNonEmptyNewLeafs = Math.min(
        parseInt((poseidon([queueId]) & 63n).toString()) + 32,
        64,
    );
    const emptyLeafsNum = 64 - nNonEmptyNewLeafs;

    // Generate queue UTXOs as
    const utxos = Array(nNonEmptyNewLeafs)
        .fill(1)
        .map((v, i) => oneInputHash(queueId * 64 + i + 1));

    // Compute commitment to queue UTXOs, `queueCommitment`
    const newLeafsCommitment = utxos
        .slice(1, nNonEmptyNewLeafs)
        .reduce((a, v) => twoInputHash(a, v), utxos[0]);

    // Generate a batch with leafs being queued UTXOs appended by zero value leafs
    const newLeafs = utxos.concat(Array(emptyLeafsNum).fill(emptyLeaf));

    // Compute the root of the batch, `batchRoot`
    let nodes = [].concat(...newLeafs);
    while (nodes.length > 1)
        nodes = Array(nodes.length >> 1)
            .fill(0)
            .map((v, i) => twoInputHash(nodes[2 * i], nodes[2 * i + 1]));
    const [batchRoot] = nodes;

    // Return Batch data
    return {newLeafs, nNonEmptyNewLeafs, newLeafsCommitment, batchRoot};
}
console.info(`1 (of 6). Generating ${nBatches} queues (and batches)`);

const batches = Array(nBatches)
    .fill(0)
    .map((_, i) => generateBatchData(i));

/**** 2. Define test scenario ***/

// The order of Batches queueing and insertion follows ("steps of a scenario").
// Batches must be queued in sequential order (0, 1, 2, 3 ...).
// Queueing a Batch must precede its insertion.
// A partially populated Batch must be inserted before queueing the next Batch.
// A fully populated Batch may be inserted after other Batches have been queued.
const scenarioSteps = [
    {queued: 0},
    {inserted: 0},
    {queued: 1},
    {queued: 2},
    {queued: 3},
    {inserted: 1},
    {inserted: 3},
    {queued: 4},
    {inserted: 2},
    {queued: 5},
    {queued: 6},
    {inserted: 6},
    {queued: 7},
    {inserted: 5},
    {inserted: 7},
    {inserted: 4},
    {queued: 8},
    {queued: 9},
    {inserted: 9},
    {inserted: 8},
    {queued: 10},
    {inserted: 10},
    {queued: 11},
    {inserted: 11},
    {queued: 12},
    {inserted: 12},
    {queued: 13},
    {queued: 14},
    {inserted: 13},
    {inserted: 14},
    {queued: 15},
    {inserted: 15},
    {queued: 16},
    {inserted: 16},
    {queued: 17},
    {inserted: 17},
    {queued: 18},
    {queued: 19},
    {inserted: 19},
    {queued: 20},
    {inserted: 18},
    {queued: 21},
    {inserted: 20},
    {inserted: 21},
    {queued: 22},
    {inserted: 22},
    {queued: 23},
    {queued: 24},
    {inserted: 24},
    {queued: 25},
    {inserted: 25},
    {queued: 26},
    {inserted: 26},
    {queued: 27},
    {inserted: 27},
    {queued: 28},
    {inserted: 28},
    {queued: 29},
    {inserted: 29},
    {queued: 30},
    {queued: 31},
    {inserted: 31},
    {inserted: 30},
    {inserted: 23},
].slice(0, nBatches * 2);

console.info(`2 (of 6). Defining ${scenarioSteps.length} scenario steps`);

const queuedBatches = scenarioSteps
    .filter(v => v.hasOwnProperty('queued'))
    .map(v => v.queued);
const insertedBatches = scenarioSteps
    .filter(v => v.hasOwnProperty('inserted'))
    .map(v => v.inserted);
assert(
    scenarioSteps.length === queuedBatches.length + insertedBatches.length,
    'unexpected number of scenario steps',
);

// Let's do sanity checks on the order of scenario steps
assert(
    queuedBatches.length === nBatches,
    `${nBatches - queuedBatches.length} batches are not queued`,
);
assert(
    insertedBatches.length === nBatches,
    `${nBatches - insertedBatches.length} batches are not inserted`,
);

queuedBatches.forEach((v, i, a) => {
    if (i === 0) {
        assert(v === 0, 'Batch 0 must be queued 1st');
    } else {
        assert(a[i - 1] + 1 === v, `Batch ${v} queued in incorrect order`);
    }
});

(function (perBatchStats) {
    perBatchStats.forEach((v, i) => {
        assert(
            v.insertionStep >= v.queueingStep,
            `batch ${i} inserted before it queued`,
        );
        if (v.isPart) {
            const curStep = v.queueingStep;
            if (curStep === scenarioSteps.length - 1) return;
            const nextQueuingStep =
                curStep +
                1 +
                scenarioSteps
                    .slice(curStep + 1, scenarioSteps.length)
                    .findIndex(s => s.hasOwnProperty('queued'));
            assert(
                nextQueuingStep > v.insertionStep,
                `Partially populated batch ${i} inserted after next batch queued`,
            );
        }
    });
})(
    scenarioSteps.reduce(
        (a, v, i) => {
            if (v.hasOwnProperty('queued')) {
                if (a[v.queued].hasOwnProperty('queueingStep'))
                    throw new Error(`Batch ${v.queued} queued twice`);
                a[v.queued].queueingStep = i;
            }
            if (v.hasOwnProperty('inserted')) {
                if (a[v.inserted].hasOwnProperty('insertionStep'))
                    throw new Error(`Batch ${v.inserted} inserted twice`);
                a[v.inserted].insertionStep = i;
                a[v.inserted].isPart =
                    batches[v.inserted].nNonEmptyNewLeafs < 64;
            }
            return a;
        },
        Array(nBatches)
            .fill(1)
            .map(() => ({})),
    ),
);

/**** 3. Compute insertions of Batches into the Bus Tree ***/

// Part of the Bus Tree, starting from Batch roots as leafs, ending with the Branch root.
// Initially, it is an empty tree. Every insertion of a Batch changes its root.
const branchTree = {
    levels: 10,
    root: emptyBranchRoot,
    getEmptyNode: getEmptyNodeAtGivenNumLevelsAboveBatchRoots,
    filledNodes: Array(10),
};

// Upper part of the Bus Tree, starting from Branch roots as leafs, up to the Bus Tree root.
// Initially, it is an empty tree. Every insertion of a Batch changes its root.
const busTree = {
    levels: 10,
    root: emptyBusTreeRoot,
    getEmptyNode: getEmptyNodeAtGivenNumLevelsAboveBranchRoots,
    filledNodes: Array(10),
};

function insertLeaf(tree, leaf, leafInd) {
    let res = {
        oldRoot: tree.root,
        newRoot: leaf,
        leafInd,
        leaf,
        siblings: Array(tree.levels),
    };
    let i = leafInd;
    for (let l = 0; l < tree.levels; l++) {
        const isRightNode = i & 1;
        if (isRightNode) {
            res.siblings[l] = tree.filledNodes[l];
            res.newRoot = twoInputHash(res.siblings[l], res.newRoot);
        } else {
            tree.filledNodes[l] = res.newRoot;
            res.siblings[l] = tree.getEmptyNode(l);
            res.newRoot = twoInputHash(res.newRoot, res.siblings[l]);
        }
        i = i >> 1;
    }
    tree.root = res.newRoot;
    return res;
}

console.info(
    `3 (of 6). Computing bus tree roots for ${insertedBatches.length} insertions`,
);

const inBranchTreeInserts = insertedBatches.map((v, i) =>
    insertLeaf(branchTree, batches[v].batchRoot, i),
);

const inBusTreeInserts = insertedBatches.map((v, i) =>
    insertLeaf(busTree, inBranchTreeInserts[i].newRoot, i >> 10),
);

/**** 4. Aggregate input for SNARK-proof ***/
const proofInputs = inBusTreeInserts.map((v, i) => ({
    oldRoot: v.oldRoot,
    newRoot: v.newRoot,
    replacedNodeIndex: i,
    pathElements: inBranchTreeInserts[i].siblings.concat(...v.siblings),
    newLeafsCommitment: batches[insertedBatches[i]].newLeafsCommitment,
    nNonEmptyNewLeafs: batches[insertedBatches[i]].nNonEmptyNewLeafs,
    newLeafs: batches[insertedBatches[i]].newLeafs,
    batchRoot: batches[insertedBatches[i]].batchRoot,
    branchRoot: inBranchTreeInserts[i].newRoot,
    extraInput: '0x7BAe1c04e5Cef0E5d635ccC0D782A21aCB920BeB',
    magicalConstraint: '0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00',
}));

/*** 5. Define SNARK-proof generator ***/

async function generateProofs(proofInputs) {
    const {groth16} = require('snarkjs');
    const wc = require('./wasm/witness_calculator');
    const wasmBuf = readFileSync(
        join(__dirname, './wasm/pantherBusTreeUpdater.wasm'),
    );
    const vk = require('./verificationKeys/VK_pantherBusTreeUpdater.json');
    const pkPath = join(
        __dirname,
        './provingKeys/pantherBusTreeUpdater_final.zkey',
    );

    const proofs = [];
    let counter = 1;
    for await (const input of proofInputs) {
        console.info(`- proof ${counter++} out of ${proofInputs.length}`);
        // As it's just simulation, assertion `input[..] < SNARK_FIELD_SIZE` skipped
        const wtnsBuf = await wc(wasmBuf).then(async witCalc =>
            witCalc.calculateWTNSBin(input, 0),
        );
        const {proof: lProof, publicSignals} = await groth16.prove(
            pkPath,
            wtnsBuf,
            null,
        );
        assert(await groth16.verify(vk, publicSignals, lProof, null));
        const solProof = (replica => [
            replica.pi_a.slice(0, 2),
            replica.pi_b.slice(0, 2).map(x => x.reverse()),
            replica.pi_c.slice(0, 2),
        ])(JSON.parse(JSON.stringify(lProof)));
        proofs.push(solProof);
    }
    return proofs;
}

/*** 6. Define scenario compiler ***/

const compileScenario = proofs =>
    scenarioSteps.map((v, i) => {
        if (v.hasOwnProperty('queued')) {
            const b = batches[v.queued];
            const queue = b.newLeafs.slice(0, b.nNonEmptyNewLeafs);
            // Decompose the queue in chunks with pseudo-random length of 1..8 UTXOs
            const queueChunks = [];
            let pos = 0;
            while (pos < queue.length) {
                const chunkSize = Math.min(
                    (parseInt(queue[pos].slice(4)) & 7) + 1,
                    queue.length - pos,
                );
                const chunkInd = queueChunks.push([]) - 1;
                for (let n = 0; n < chunkSize; n++) {
                    queueChunks[chunkInd].push(queue[pos + n]);
                }
                pos += chunkSize;
            }
            return {
                description: `Step #${i}: Queue the Batch.${v.queued}`,
                calls: queueChunks.map(v => ({
                    method: 'simulateAddUtxosToBusQueue(bytes32[] utxos, uint96 reward)',
                    params: [v, v.length * 10],
                })),
            };
        } else if (v.hasOwnProperty('inserted')) {
            const proofIndex = insertedBatches.findIndex(
                batchNum => batchNum === v.inserted,
            );
            assert(
                proofIndex >= 0,
                `PANIC!!! proof input for batch ${v.inserted} missing`,
            );
            const inp = proofInputs[proofIndex];
            assert(
                batches[v.inserted].batchRoot === inp.batchRoot,
                `PANIC!!! Mismatching batchRoot in proof input for batch ${v.inserted}`,
            );
            return {
                description: `Step #${i}: Insert the Batch.${v.inserted}`,
                calls: [
                    {
                        method: 'onboardQueue(address miner, uint32 queueId, bytes32 busTreeNewRoot, bytes32 batchRoot, bytes32 busBranchNewRoot, SnarkProof memory proof)',
                        params: [
                            inp.extraInput,
                            v.inserted,
                            inp.newRoot,
                            inp.batchRoot,
                            inp.branchRoot,
                            proofs[proofIndex],
                        ],
                    },
                ],
            };
        }
    });

/*** 6. Finally, run proof generator, scenario compiler, and write results ***/

console.info(
    `4 (of 6). Generating proofs for ${insertedBatches.length} insertions`,
);
generateProofs(proofInputs).then(proofs => {
    console.info(`5 (of 6). Compiling scenario data`);
    const scenario = compileScenario(proofs);

    console.info(`6 (of 6). Writing result files`);
    const scFName = join(__dirname, './busTreeScenario.json');
    const piFName = join(__dirname, './busTreeScenario.proofInput.json');
    writeFileSync(scFName, JSON.stringify(scenario, null, 2) + `\n`);
    writeFileSync(piFName, JSON.stringify(proofInputs, null, 2) + `\n`);

    console.info(
        `DONE: Scenario has been generated and save in\n${scFName}\n${piFName}`,
    );
    process.exit(0);
});
