import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

//import {babyjub} from 'circomlibjs';
//const F = babyjub.F;

import {getOptions} from './helpers/circomTester';
import {wtns, groth16} from 'snarkjs';

import {MerkleTree} from "@zk-kit/merkle-tree";
import {TriadMerkleTree} from "@panther-core/crypto/lib/other/triad-merkle-tree";
import assert from "assert";

import {poseidon} from "circomlibjs";
// import {zeroLeaf} from "@panther-core/contracts/lib/utilities";
import {deriveKeypairFromSeed} from "@panther-core/crypto/lib/base/keypairs";

describe('MainTransactionV1Extended circuit - TODO: IMPLEMENT', async function (this: any) {
    const poseidon2or3 = (inputs: bigint[]): bigint => {
        assert(inputs.length === 3 || inputs.length === 2);
        return poseidon(inputs);
    };

    let circuit: any;
    let mainTxWasm: any;
    let mainTxWitness: any;
    let mainTxZKey: any;
    let mainTxVKey: any;
    let mainTxVKeyJSON: any;

    let triadMerkleTree: any;
    let zAssetMerkleTree: any;
    let zoneRecordMerkleTree: any;
    let zAccountBlackListMerkleTree: any;
    let kycKytMerkleTree: any;
    let rootSenderKeys: any;
    let rootRecipientKeys: any;

    // Special type - used to check everything in isolation
    const zeroInput = {
        publicInputsHash: BigInt('0'),
        extraInputsHash: BigInt('0'),
        publicZAsset: BigInt('0'),
        depositAmount: BigInt('0'),
        withdrawAmount: BigInt('0'),
        privateZAsset: BigInt('0'),
        zAssetWeight: BigInt('0'),
        zAssetMerkleRoot: BigInt('0'),
        zAssetPathIndex: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        zAssetPathElements: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        forTxReward: BigInt('0'),
        forUtxoReward: BigInt('0'),
        forDepositReward: BigInt('0'),
        spendTime: BigInt('0'),
        utxoInSpendPrivKey: [BigInt('0'), BigInt('0')],
        utxoInRootSpendPrivKey: [BigInt('0'), BigInt('0')],
        utxoInAmount: [BigInt('0'), BigInt('0')],
        utxoInOriginZoneId: [BigInt('0'), BigInt('0')],
        utxoInOriginZoneIdOffset: [BigInt('0'), BigInt('0')],
        utxoInOriginNetworkId: [BigInt('0'), BigInt('0')],
        utxoInTargetNetworkId: [BigInt('0'), BigInt('0')],
        utxoInCreateTime: [BigInt('0'), BigInt('0')],
        utxoInTreeNumber: [BigInt('0'), BigInt('0')],
        utxoInMerkleRoot: [BigInt('0'), BigInt('0')],
        utxoInPathIndex: [
            [
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
            ],
            [
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
            ],
        ],
        utxoInPathElements: [
            [
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
            ],
            [
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
                BigInt('0'),
            ],
        ],
        zAccountUtxoInId: BigInt('0'),
        zAccountUtxoInZkpAmount: BigInt('0'),
        zAccountUtxoInPrpAmount: BigInt('0'),
        zAccountUtxoInZoneId: BigInt('0'),
        zAccountUtxoInExpiryTime: BigInt('0'),
        zAccountUtxoInNonce: BigInt('0'),
        zAccountUtxoInTotalAmountPerTimePeriod: BigInt('0'),
        zAccountUtxoInCreateTime: BigInt('0'),
        zAccountUtxoInRootSpendPubKey: [BigInt('0'), BigInt('0')],
        zAccountUtxoInMasterEOA: BigInt('0'),
        zAccountUtxoInSpendPrivKey: BigInt('0'),
        zAccountUtxoInTreeNumber: BigInt('0'),
        zAccountUtxoInMerkleRoot: BigInt('0'),
        zAccountUtxoInPathIndices: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        zAccountUtxoInPathElements: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        zAccountBlackListLeaf: BigInt('0'),
        zAccountBlackListMerkleRoot: BigInt('0'),
        zAccountBlackListPathElements: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        zoneRecordOriginZonesList: BigInt('0'),
        zoneRecordTargetZonesList: BigInt('0'),
        zoneRecordNetworkIDsBitMap: BigInt('0'),
        zoneRecordKycKytMerkleTreeLeafIDsAndRulesList: BigInt('0'),
        zoneRecordKycExpiryTime: BigInt('0'),
        zoneRecordKytExpiryTime: BigInt('0'),
        zoneRecordDepositMaxAmount: BigInt('0'),
        zoneRecordWithrawMaxAmount: BigInt('0'),
        zoneRecordInternalMaxAmount: BigInt('0'),
        zoneRecordMerkleRoot: BigInt('0'),
        zoneRecordPathElements: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        zoneRecordPathIndex: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        zoneRecordEdDsaPubKey: [BigInt('0'), BigInt('0')],
        zoneRecordDataEscrowEphimeralRandom: BigInt('0'),
        zoneRecordZAccountIDsBlackList: BigInt('1766847064778384329583297500742918515827483896875618958121606201292619775'),
        zoneRecordMaximumAmountPerTimePeriod: BigInt('0'),
        zoneRecordTimePeriodPerMaximumAmount: BigInt('0'),
        kytEdDsaPubKey: [BigInt('0'), BigInt('0')],
        kytEdDsaPubKeyExpiryTime: BigInt('0'),
        kytSignedMessage: [BigInt('0'), BigInt('0')],
        kytSignedMessageHash: BigInt('0'),
        kytSignature: [BigInt('0'), BigInt('0'), BigInt('0')],
        kycKytMerkleRoot: BigInt('0'),
        kytPathElements: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        kytPathIndex: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        kytMerkleTreeLeafIDsAndRulesOffset: BigInt('0'),
        dataEscrowPubKey: [BigInt('0'), BigInt('0')],
        dataEscrowPubKeyExpiryTime: BigInt('0'),
        dataEscrowEphimeralRandom: BigInt('0'),
        dataEscrowPathElements: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        dataEscrowPathIndex: [
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
            BigInt('0'),
        ],
        daoDataEscrowPubKey: [BigInt('0'), BigInt('0')],
        daoDataEscrowEphimeralRandom: BigInt('0'),
        utxoOutCreateTime: BigInt('0'),
        utxoOutAmount: [BigInt('0'), BigInt('0')],
        utxoOutOriginNetworkId: [BigInt('0'), BigInt('0')],
        utxoOutTargetNetworkId: [BigInt('0'), BigInt('0')],
        utxoOutTargetZoneId: [BigInt('0'), BigInt('0')],
        utxoOutTargetZoneIdOffset: [BigInt('0'), BigInt('0')],
        utxoOutSpendPubKeyRandom: [BigInt('0'), BigInt('0')],
        utxoOutRootSpendPubKey: [
            [BigInt('0'), BigInt('0')],
            [BigInt('0'), BigInt('0')],
        ],
        zAccountUtxoOutZkpAmount: BigInt('0'),
        zAccountUtxoOutSpendKeyRandom: BigInt('0'),
        chargedAmountZkp: BigInt('0'),
    };
    // WIll be filled during deposit, withdraw, masp-internal and mix of d/w/i
    let nonZeroInput = zeroInput;

    this.timeout(10000000);

    before(async () => {
        // witness part - for unit-tests
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './circuits/mainTransaction_v1_extended.circom',
        );
        circuit = await wasm_tester(input, opts);
        // full proof part - for integration-tests
        mainTxWasm = path.join(
            opts.basedir,
            './compiled/mainTransaction_v1_extended_js/mainTransaction_v1_extended.wasm',
        );
        mainTxWitness = path.join(
            opts.basedir,
            './compiled/mainTransaction_v1_extended',
        );
        mainTxZKey = path.join(
            opts.basedir,
            './compiled/mainTransaction_v1_extended_final.zkey',
        );
        mainTxVKey = path.join(
            opts.basedir,
            './compiled/mainTransaction_v1_extended_verification_key.json',
        );
        mainTxVKeyJSON = require(mainTxVKey);

        // NOTE: depths values can be taken from: mainTransaction_v1_extended.circom
        triadMerkleTree = new TriadMerkleTree(16,BigInt('0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d'),poseidon2or3);

        zAssetMerkleTree = new MerkleTree(poseidon2or3,16, BigInt(0));
        zoneRecordMerkleTree = new MerkleTree(poseidon2or3,16, BigInt(0));
        zAccountBlackListMerkleTree = new MerkleTree(poseidon2or3,16,BigInt(0));
        kycKytMerkleTree = new MerkleTree(poseidon2or3,16,BigInt(0));

        rootSenderKeys = deriveKeypairFromSeed(BigInt(0x0123456789ABCDEF));
        rootRecipientKeys = deriveKeypairFromSeed(BigInt(0x0123456789ABCDEF));
    });

    it('Should compute valid witness', async () => {
        const w = await circuit.calculateWitness(zeroInput, true);

        //await circuit.assertOut(w, {rAmount: rAmount});
    });

    it('Should compute valid full-proccess proof with zero-input', async () => {
        await wtns.calculate(zeroInput, mainTxWasm, mainTxWitness, null);
        const prove = await groth16.prove(mainTxZKey, mainTxWitness, null);
        const proof = prove.proof;
        const publicSignals = prove.publicSignals;

        const verify = await groth16.verify(
            mainTxVKeyJSON,
            publicSignals,
            proof,
            null,
        );

        if (verify === true) {
            console.log('Verification OK');
        } else {
            console.log('Invalid proof');
        }
    });

    it('Should compute valid full-proccess proof with deposit-input (w/o public-hash)', async () => {

    });

    it('Should compute valid full-proccess proof with withdraw-input (w/o public-hash)', async () => {

    });

    it('Should compute valid full-proccess proof with deposit-withdraw-input (w/o public-hash)', async () => {

    });

    it('Should compute valid full-proccess proof with masp-internal-input (w/o public-hash)', async () => {

    });

    it('Should compute valid full-proof', async () => {
        // console.log("Start:", new Date());
        /*
        const {fullProof, fullPublicSignals} = await snarkjs.groth16.fullProve(
            {
                "publicInputsHash": "0",
                "extraInputsHash": "0",
                "publicZAsset": "0",
                "depositAmount": "0",
                "withdrawAmount": "0",
                "privateZAsset": "0",
                "zAssetWeight": "0",
                "zAssetMerkleRoot": "0",
                "zAssetPathIndex": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "zAssetPathElements": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "forTxReward": "0",
                "forUtxoReward": "0",
                "forDepositReward": "0",
                "spendTime": "0",
                "utxoInSpendPrivKey": ["0", "0"],
                "utxoInRootSpendPrivKey": ["0", "0"],
                "utxoInAmount": ["0", "0"],
                "utxoInOriginZoneId": ["0", "0"],
                "utxoInOriginZoneIdOffset": ["0", "0"],
                "utxoInOriginNetworkId": ["0", "0"],
                "utxoInTargetNetworkId": ["0", "0"],
                "utxoInCreateTime": ["0", "0"],
                "utxoInTreeNumber": ["0", "0"],
                "utxoInMerkleRoot": ["0", "0"],
                "utxoInPathIndex": [["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"], ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"]],
                "utxoInPathElements": [["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"], ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"]],
                "zAccountUtxoInId": "0",
                "zAccountUtxoInZkpAmount": "0",
                "zAccountUtxoInPrpAmount": "0",
                "zAccountUtxoInZoneId": "0",
                "zAccountUtxoInExpiryTime": "0",
                "zAccountUtxoInNonce": "0",
                "zAccountUtxoInTotalAmountPerTimePeriod": "0",
                "zAccountUtxoInCreateTime": "0",
                "zAccountUtxoInRootSpendPubKey": ["0", "0"],
                "zAccountUtxoInMasterEOA": "0",
                "zAccountUtxoInSpendPrivKey": "0",
                "zAccountUtxoInTreeNumber": "0",
                "zAccountUtxoInMerkleRoot": "0",
                "zAccountUtxoInPathIndices": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"],
                "zAccountUtxoInPathElements": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16"],
                "zAccountBlackListLeaf": "0",
                "zAccountBlackListMerkleRoot": "0",
                "zAccountBlackListPathElements": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "zoneRecordOriginZonesList": "0",
                "zoneRecordTargetZonesList": "0",
                "zoneRecordNetworkIDsBitMap": "0",
                "zoneRecordKycKytMerkleTreeLeafIDsAndRulesList": "0",
                "zoneRecordKycExpiryTime": "0",
                "zoneRecordKytExpiryTime": "0",
                "zoneRecordDepositMaxAmount": "0",
                "zoneRecordWithrawMaxAmount": "0",
                "zoneRecordInternalMaxAmount": "0",
                "zoneRecordMerkleRoot": "0",
                "zoneRecordPathElements": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "zoneRecordPathIndex": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "zoneRecordEdDsaPubKey": ["0", "0"],
                "zoneRecordDataEscrowEphimeralRandom": "0",
                "zoneRecordZAccountIDsBlackList": "1766847064778384329583297500742918515827483896875618958121606201292619775",
                "zoneRecordMaximumAmountPerTimePeriod": "0",
                "zoneRecordTimePeriodPerMaximumAmount": "0",
                "kytEdDsaPubKey": ["0", "0"],
                "kytEdDsaPubKeyExpiryTime": "0",
                "kytSignedMessage": ["0", "0"],
                "kytSignedMessageHash": "0",
                "kytSignature": ["0", "0", "0"],
                "kycKytMerkleRoot": "0",
                "kytPathElements": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "kytPathIndex": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "kytMerkleTreeLeafIDsAndRulesOffset": "0",
                "dataEscrowPubKey": ["0", "0"],
                "dataEscrowPubKeyExpiryTime": "0",
                "dataEscrowEphimeralRandom": "0",
                "dataEscrowPathElements": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "dataEscrowPathIndex": ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"],
                "daoDataEscrowPubKey": ["0", "0"],
                "daoDataEscrowEphimeralRandom": "0",
                "utxoOutCreateTime": "0",
                "utxoOutAmount": ["0", "0"],
                "utxoOutOriginNetworkId": ["0", "0"],
                "utxoOutTargetNetworkId": ["0", "0"],
                "utxoOutTargetZoneId": ["0", "0"],
                "utxoOutTargetZoneIdOffset": ["0", "0"],
                "utxoOutSpendPubKeyRandom": ["0", "0"],
                "utxoOutRootSpendPubKey": [["0", "0"], ["0", "0"]],
                "zAccountUtxoOutZkpAmount": "0",
                "zAccountUtxoOutSpendKeyRandom": "0",
                "chargedAmountZkp": "0"
            },
            mainTxWasm,
            mainTxZKey
        );


        // console.log("End:", new Date());
        console.log(mainTxWasm);
        console.log(mainTxZKey);
        const {fullProof, fullPublicSignals} = await snarkjs.groth16.fullProve(zeroInput, mainTxWasm, mainTxZKey);
        console.log("Proof: ");
        console.log(JSON.stringify(await fullProof, null, 1));

        const res = await snarkjs.groth16.verify(mainTxVKey, fullPublicSignals, fullProof);

        if (res === true) {
            console.log("Verification OK");
        } else {
            console.log("Invalid proof");
        } */
    });
});
