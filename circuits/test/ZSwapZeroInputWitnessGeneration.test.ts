import * as path from 'path';

import circom_wasm_tester from 'circom_tester';
const wasm_tester = circom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {wtns} from 'snarkjs';

describe('ZSwap - ZeroInput - Witness computation', async function (this: any) {
    let circuit: any;
    let ammWasm: any;
    let ammWitness: any;

    this.timeout(10_000_000);

    before(async () => {
        const opts = getOptions();
        const input = path.join(opts.basedir, './circuits/mainZSwapV1.circom');
        circuit = await wasm_tester(input, opts);

        ammWasm = path.join(opts.basedir, './compiled/zSwap/circuits.wasm');

        ammWitness = path.join(opts.basedir, './compiled/generateWitness.js');
    });

    const zeroInput = {
        extraInputsHash: 0,

        depositAmount: 0,
        withdrawAmount: 0,
        addedAmountZkp: 0,

        token: [0, 0],
        tokenId: [0, 0],
        utxoZAsset: [0, 0],

        zAssetId: [0, 0, 0],
        zAssetToken: [0, 0, 0],
        zAssetTokenId: [0, 0, 0],
        zAssetNetwork: [0, 0, 0],
        zAssetOffset: [0, 0, 0],
        zAssetWeight: [0, 0, 0],
        zAssetScale: [1, 1, 1],
        zAssetMerkleRoot: 0,
        zAssetPathIndices: [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        ],
        zAssetPathElements: [
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        ],

        forTxReward: 0,
        forUtxoReward: 0,
        forDepositReward: 0,

        spendTime: 0,

        utxoInSpendPrivKey: [0, 0],
        utxoInSpendKeyRandom: [0, 0],
        utxoInAmount: [0, 0],
        utxoInOriginZoneId: [0, 0],
        utxoInOriginZoneIdOffset: [0, 0],
        utxoInOriginNetworkId: [0, 0],
        utxoInTargetNetworkId: [0, 0],
        utxoInCreateTime: [0, 0],
        utxoInZAccountId: [0, 0],
        utxoInMerkleTreeSelector: [
            [0, 0],
            [0, 0],
        ],
        utxoInPathIndices: [
            [
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ],
            [
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ],
        ],
        utxoInPathElements: [
            [
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ],
            [
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            ],
        ],
        utxoInNullifier: [0, 0],
        utxoInDataEscrowPubKey: [
            [0, 0],
            [0, 0],
        ],

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
        zAccountUtxoInMasterEOA: 0,
        zAccountUtxoInSpendPrivKey: 0,
        zAccountUtxoInReadPrivKey: 0,
        zAccountUtxoInNullifierPrivKey: 0,
        zAccountUtxoInMerkleTreeSelector: [0, 0],
        zAccountUtxoInPathIndices: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],
        zAccountUtxoInPathElements: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],
        zAccountUtxoInNullifier: 0,

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
        zZoneEdDsaPubKey: [0, 0],
        zZoneDataEscrowEphemeralRandom: 0,
        zZoneDataEscrowEphemeralPubKeyAx: 0,
        zZoneDataEscrowEphemeralPubKeyAy: 1,
        zZoneZAccountIDsBlackList:
            '1766847064778384329583297500742918515827483896875618958121606201292619775',
        zZoneMaximumAmountPerTimePeriod: 0,
        zZoneTimePeriodPerMaximumAmount: 0,
        zZoneSealing: 0,

        zZoneDataEscrowEncryptedMessage: [
            12531734342052619194565643021324392392429746097842075389394984433885012062201n,
        ],
        zZoneDataEscrowEncryptedMessageHmac:
            12139889566189079074982092153889150195624803619631670043035373395283737385426n,

        kytEdDsaPubKey: [0, 0],
        kytEdDsaPubKeyExpiryTime: 0,
        trustProvidersMerkleRoot: 0,
        kytPathElements: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        kytPathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        kytMerkleTreeLeafIDsAndRulesOffset: 0,

        kytDepositSignedMessagePackageType: 2,
        kytDepositSignedMessageTimestamp: 0,
        kytDepositSignedMessageSender: 0,
        kytDepositSignedMessageReceiver: 0,
        kytDepositSignedMessageToken: 0,
        kytDepositSignedMessageSessionId: 0,
        kytDepositSignedMessageRuleId: 0,
        kytDepositSignedMessageAmount: 0,
        kytDepositSignedMessageChargedAmountZkp: 0,
        kytDepositSignedMessageSigner: 0,
        kytDepositSignedMessageHash: 0,
        kytDepositSignature: [0, 0, 0],

        kytWithdrawSignedMessagePackageType: 2,
        kytWithdrawSignedMessageTimestamp: 0,
        kytWithdrawSignedMessageSender: 0,
        kytWithdrawSignedMessageReceiver: 0,
        kytWithdrawSignedMessageToken: 0,
        kytWithdrawSignedMessageSessionId: 0,
        kytWithdrawSignedMessageRuleId: 0,
        kytWithdrawSignedMessageAmount: 0,
        kytWithdrawSignedMessageChargedAmountZkp: 0,
        kytWithdrawSignedMessageSigner: 0,
        kytWithdrawSignedMessageHash: 0,
        kytWithdrawSignature: [0, 0, 0],

        kytSignedMessagePackageType: 253,
        kytSignedMessageTimestamp: 0,
        kytSignedMessageSessionId: 0,
        kytSignedMessageChargedAmountZkp: 0,
        kytSignedMessageSigner: 0,
        kytSignedMessageDataEscrowHash: 0,
        kytSignedMessageHash: 0,
        kytSignature: [0, 0, 0],

        dataEscrowPubKey: [0, 0],
        dataEscrowPubKeyExpiryTime: 0,
        dataEscrowEphemeralRandom: 0,
        dataEscrowEphemeralPubKeyAx: 0,
        dataEscrowEphemeralPubKeyAy: 1,
        dataEscrowPathElements: [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],
        dataEscrowPathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],

        dataEscrowEncryptedMessage: [
            12531734342052619194565643021324392392429746097842075389394984433885012062201n,
            17943901642092756540532360474161569402553221410028090072917443956036363428842n,
            11790059851550142146278072775670916642282838830554510149311470233718605478544n,
            3837132928506022228781468748174933227664304248895366259202309016817149117447n,
            13203026333203916959031401688301750700471853677775311097828007874250103222348n,
        ],
        dataEscrowEncryptedMessageHmac:
            4366907063267177208632913799665498714653211878072617913621531629611244564979n,

        daoDataEscrowPubKey: [0, 0],
        daoDataEscrowEphemeralRandom: 0,
        daoDataEscrowEphemeralPubKeyAx: 0,
        daoDataEscrowEphemeralPubKeyAy: 1,

        daoDataEscrowEncryptedMessage: [
            12531734342052619194565643021324392392429746097842075389394984433885012062201n,
        ],
        daoDataEscrowEncryptedMessageHmac:
            12139889566189079074982092153889150195624803619631670043035373395283737385426n,

        utxoOutCreateTime: 0,
        utxoOutAmount: [0, 0],
        utxoOutOriginNetworkId: [0, 0],
        utxoOutTargetNetworkId: [0, 0],
        utxoOutTargetZoneId: [0, 0],
        utxoOutTargetZoneIdOffset: [0, 0],
        utxoOutSpendPubKeyRandom: [0, 0],
        utxoOutRootSpendPubKey: [
            [0, 1],
            [0, 1],
        ],
        utxoOutCommitment: [0, 0],

        zAccountUtxoOutZkpAmount: 0,
        zAccountUtxoOutSpendKeyRandom: 0,
        zAccountUtxoOutCommitment:
            16885803331448709892763712024861110241825210009328264441474415468494162175579n,

        chargedAmountZkp: 0,

        zNetworkId: 0,
        zNetworkChainId: 0,
        zNetworkIDsBitMap: 0,
        zNetworkTreeMerkleRoot: 0,
        zNetworkTreePathElements: [0, 0, 0, 0, 0, 0],
        zNetworkTreePathIndices: [0, 0, 0, 0, 0, 0],

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
        await wtns.calculate(zeroInput, ammWasm, ammWitness, null);
        console.log('Witness calculation successful!');
    });
});
