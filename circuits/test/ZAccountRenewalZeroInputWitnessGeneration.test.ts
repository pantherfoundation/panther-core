import * as path from 'path';

import circom_wasm_tester from 'circom_tester';
const wasm_tester = circom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {wtns} from 'snarkjs';

describe('ZAccount Renewal - ZeroInput - Witness computation', async function (this: any) {
    let circuit: any;
    let mainZAccountRenewalWasm: any;
    let mainZAccountRenewalWitness: any;

    this.timeout(10_000_000);

    before(async () => {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './circuits/mainZAccountRenewalV1.circom',
        );
        circuit = await wasm_tester(input, opts);

        mainZAccountRenewalWasm = path.join(
            opts.basedir,
            './compiled/zAccountRenewal/circuits.wasm',
        );

        mainZAccountRenewalWitness = path.join(
            opts.basedir,
            './compiled/generate_witness.js',
        );
    });

    const zeroInput = {
        extraInputsHash: 0,

        addedAmountZkp: 0,

        chargedAmountZkp: 0,

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
        zAccountUtxoInRootSpendPrivKey: 0,
        zAccountUtxoInRootSpendPubKey: [0, 1],
        zAccountUtxoInReadPubKey: [0, 1],
        zAccountUtxoInNullifierPubKey: [0, 1],
        zAccountUtxoInMasterEOA: 0,
        zAccountUtxoInSpendKeyRandom: 0,
        zAccountUtxoInNullifierPrivKey: [0],
        zAccountUtxoInCommitment: 0,
        zAccountUtxoInNullifier: 0,
        zAccountUtxoInMerkleTreeSelector: [0, 0],
        zAccountUtxoInPathIndices: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],
        zAccountUtxoInPathElements: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],

        zAccountUtxoOutZkpAmount: 0,
        zAccountUtxoOutExpiryTime: 0,
        zAccountUtxoOutCreateTime: 0,
        zAccountUtxoOutSpendKeyRandom: 0,
        zAccountUtxoOutCommitment: 0,

        zAccountBlackListLeaf: 0,
        zAccountBlackListMerkleRoot: 0,
        zAccountBlackListPathElements: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],

        zZoneOriginZoneIDs: 0,
        zZoneTargetZoneIDs: 0,
        zZoneNetworkIDsBitMap: 0,
        zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList: 0,
        zZoneKycExpiryTime: 0,
        zZoneKytExpiryTime: 0,
        zZoneDepositMaxAmount: 0,
        zZoneWithdrawMaxAmount: 0,
        zZoneInternalMaxAmount: 0,
        zZoneMerkleRoot: 0,
        zZonePathElements: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zZonePathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zZoneEdDsaPubKey: [0, 1],
        zZoneZAccountIDsBlackList:
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        zZoneMaximumAmountPerTimePeriod: 0,
        zZoneTimePeriodPerMaximumAmount: 0,
        zZoneDataEscrowPubKey: [0, 1],
        zZoneSealing: 0,

        kycEdDsaPubKey: [0, 1],
        kycEdDsaPubKeyExpiryTime: 0,
        trustProvidersMerkleRoot: 0,
        kycPathElements: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        kycPathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        kycMerkleTreeLeafIDsAndRulesOffset: 0,

        kycSignedMessagePackageType: 1n,
        kycSignedMessageTimestamp: 0,
        kycSignedMessageSender: 0,
        kycSignedMessageReceiver: 0,
        kycSignedMessageSessionId: 0,
        kycSignedMessageRuleId: 0,
        kycSignedMessageChargedAmountZkp: 0,
        kycSignedMessageSigner: 0,
        kycSignedMessageHash: 0,
        kycSignature: [0, 0, 0],

        zNetworkId: 0,
        zNetworkChainId: 0,
        zNetworkIDsBitMap: 0,
        zNetworkTreeMerkleRoot: 0,
        zNetworkTreePathElements: [0, 0, 0, 0, 0, 0],
        zNetworkTreePathIndices: [0, 0, 0, 0, 0, 0],

        daoDataEscrowPubKey: [0, 1],
        forTxReward: 0,
        forUtxoReward: 0,
        forDepositReward: 0,

        staticTreeMerkleRoot: 0,

        forestMerkleRoot: 0,
        taxiMerkleRoot: 0,
        busMerkleRoot: 0,
        ferryMerkleRoot: 0,

        salt: 0,
        saltHash: 0,

        magicalConstraint: 0,
    };

    it('should compute valid witness for zero input tx', async () => {
        await wtns.calculate(
            zeroInput,
            mainZAccountRenewalWasm,
            mainZAccountRenewalWitness,
            null,
        );
        console.log('Witness calculation successful!');
    });
});
