import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {babyjub} from 'circomlibjs';
const F = babyjub.F;

import {getOptions} from './helpers/circomTester';

const snarkjs = require("snarkjs");
const fs = require("fs");


describe('MainTransactionV1Extended circuit - TODO: IMPLEMENT', async function (this: any) {
    let circuit: any;

    before(async () => {
        // witness part - for unit-tests
        const opts = getOptions();
        const input = path.join(opts.basedir, './circuits/mainTransaction_v1.circom');
        circuit = await wasm_tester(input, opts);
        // full proof part - for integration-tests
        const mainTxWasm = path.join(opts.basedir, "./compiled/mainTransaction_v1_extended_js/mainTransaction_v1_extended.wasm");
        const mainTxZKey = path.join(opts.basedir, "./compiled/mainTransaction_v1_extended_final.zkey");
        /*
        const { fullProof, fullPublicSignals } = await snarkjs.groth16.fullProve(
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
                "zAccountUtxoInTreeNumber": "0",
                "zAccountUtxoInRootSpendPubKey": ["0", "0"],
                "zAccountUtxoInMasterEOA": "0",
                "zAccountUtxoInSpendPrivKey": "0",
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
                "zoneRecordEcDsaPubKeyHash": "0",
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
                "utxoOutSpendPubKeyRandom": ["0","0"],
                "utxoOutRootSpendPubKey": [["0","0"],["0","0"]],
                "zAccountUtxoOutZkpAmount": "0",
                "zAccountUtxoOutSpendKeyRandom": "0",
                "chargedAmountZkp": "0",
            },
            mainTxWasm,
            mainTxZKey
        );

         */
    });

    it('Should compute valid witness - TODO', async function () {
    });

    it('Should compute valid full-proof - TODO', async function () {
        /*
        const input = {
            extAmountIn: F.e(10),
            forTxReward: F.e(2),
            forUtxoReward: F.e(3),
            forDepositReward: F.e(4),
            rAmountTips: F.e(2),
            amountsIn: [F.e(2), F.e(4)],
            createTimes: [F.e(10), F.e(15)],
            spendTime: F.e(20),
            assetWeight: F.e(2),
        };
        const w = await circuit.calculateWitness(input, true);

        await circuit.assertOut(w, {rAmount: rAmount});
        */
    });
});
