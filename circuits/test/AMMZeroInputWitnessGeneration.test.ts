import * as path from 'path';

import circom_wasm_tester from 'circom_tester';
const wasm_tester = circom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {wtns} from 'snarkjs';

describe('Automated Market Maker - ZeroInput - Witness computation', async function (this: any) {
    let circuit: any;
    let ammWasm: any;
    let ammWitness: any;

    this.timeout(10000000);

    before(async () => {
        const opts = getOptions();
        const input = path.join(opts.basedir, './circuits/mainAmmV1.circom');
        circuit = await wasm_tester(input, opts);

        ammWasm = path.join(
            opts.basedir,
            './compiled/prpConverter/circuits.wasm',
        );

        ammWitness = path.join(opts.basedir, './compiled/generateWitness.js');
    });

    const zeroInput = {
        // external data anchoring
        extraInputsHash: 0,

        addedAmountZkp: 0,
        chargedAmountZkp: 0,
        createTime: 0,
        depositAmountPrp: 0,
        withdrawAmountPrp: 0,

        utxoCommitment: 0,
        utxoSpendPubKey: [0, 1],
        utxoSpendKeyRandom: 0,

        // zAsset
        zAssetId: 0,
        zAssetToken: 0,
        zAssetTokenId: 0,
        zAssetNetwork: 0,
        zAssetOffset: 0,
        zAssetWeight: 0,
        zAssetScale: 1,
        zAssetMerkleRoot: 0,
        zAssetPathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zAssetPathElements: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],

        zAccountUtxoInId: 0,
        zAccountUtxoInZkpAmount: 0,
        zAccountUtxoInPrpAmount: 0,
        zAccountUtxoInZoneId: 0,
        zAccountUtxoInNetworkId: 0,
        zAccountUtxoInExpiryTime: 0,
        zAccountUtxoInNonce: 0,
        zAccountUtxoInTotalAmountPerTimePeriod: 0,
        zAccountUtxoInCreateTime: 0,
        zAccountUtxoInRootSpendPubKey: [0, 1],
        zAccountUtxoInReadPubKey: [0, 1],
        zAccountUtxoInNullifierPubKey: [0, 1],
        zAccountUtxoInSpendPrivKey: 0,
        zAccountUtxoInNullifierPrivKey: 0,
        zAccountUtxoInMasterEOA: 0,
        zAccountUtxoInSpendKeyRandom: 0,
        zAccountUtxoInCommitment: 0,
        zAccountUtxoInNullifier: 0,
        zAccountUtxoInMerkleTreeSelector: [1, 0],
        zAccountUtxoInPathIndices: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],
        zAccountUtxoInPathElements: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],

        zAccountUtxoOutZkpAmount: 0,
        zAccountUtxoOutPrpAmount: 0,
        zAccountUtxoOutSpendKeyRandom: 0,
        zAccountUtxoOutCommitment: 0,

        // blacklist merkle tree & proof of non-inclusion - zAccountId is the index-path
        zAccountBlackListLeaf: 0,
        zAccountBlackListMerkleRoot: 0,
        zAccountBlackListPathElements: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],

        // zZone
        zZoneOriginZoneIDs: 0,
        zZoneTargetZoneIDs: 0,
        zZoneNetworkIDsBitMap: 0,
        zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList: 0,
        zZoneKycExpiryTime: 0,
        zZoneKytExpiryTime: 0,
        zZoneDepositMaxAmount: 0,
        zZoneWithrawMaxAmount: 0,
        zZoneInternalMaxAmount: 0,
        zZoneMerkleRoot: 0,
        zZonePathElements: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zZonePathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zZoneEdDsaPubKey: [0, 0],
        zZoneZAccountIDsBlackList:
            '1766847064778384329583297500742918515827483896875618958121606201292619775',

        zZoneMaximumAmountPerTimePeriod: 0,
        zZoneTimePeriodPerMaximumAmount: 0,

        zNetworkId: 0,
        zNetworkChainId: 0,
        zNetworkIDsBitMap: 0,
        zNetworkTreeMerkleRoot: 0,
        zNetworkTreePathElements: [0, 0, 0, 0, 0, 0],
        zNetworkTreePathIndices: [0, 0, 0, 0, 0, 0],
        daoDataEscrowPubKey: [0, 0],
        forTxReward: 0,
        forUtxoReward: 0,
        forDepositReward: 0,

        trustProvidersMerkleRoot: 0,
        staticTreeMerkleRoot: 0,
        forestMerkleRoot: 0,
        taxiMerkleRoot: 0,
        busMerkleRoot: 0,
        ferryMerkleRoot: 0,

        // salt
        salt: 0,
        saltHash: 0,

        // magical constraint - groth16 attack: https://geometry.xyz/notebook/groth16-malleability
        magicalConstraint: 0,
    };

    it('should compute valid witness for zero input tx', async () => {
        await wtns.calculate(zeroInput, ammWasm, ammWitness, null);
        console.log('Witness calculation successful!');
    });
});
