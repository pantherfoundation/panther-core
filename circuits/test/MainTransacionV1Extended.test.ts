import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

//import {babyjub} from 'circomlibjs';
//const F = babyjub.F;

import {getOptions} from './helpers/circomTester';
import {wtns, groth16} from 'snarkjs';

import {MerkleTree} from '@zk-kit/merkle-tree';
import {TriadMerkleTree} from '@panther-core/crypto/lib/other/triad-merkle-tree';
import assert from 'assert';

import {poseidon} from 'circomlibjs';
// import {zeroLeaf} from "@panther-core/contracts/lib/utilities";
import {deriveKeypairFromSeed} from '@panther-core/crypto/lib/base/keypairs';

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

    const zeroInput = {
        extraInputsHash: BigInt(0n),

        // tx api
        depositAmount: BigInt(0n),
        depositChange: BigInt(0n),
        withdrawAmount: BigInt(0n),
        withdrawChange: BigInt(0n),
        token: BigInt(0n),
        tokenId: BigInt(0n),
        utxoZAsset: BigInt(0n),

        // zAsset
        zAssetId: BigInt(0n),
        zAssetToken: BigInt(0n),
        zAssetTokenId: BigInt(0n),
        zAssetNetwork: BigInt(0n),
        zAssetOffset: BigInt(0n),
        zAssetWeight: BigInt(0n),
        zAssetScale: BigInt(0n),
        zAssetMerkleRoot: BigInt(0n),
        zAssetPathIndex: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zAssetPathElements: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],

        // reward computation params
        forTxReward: BigInt(0n),
        forUtxoReward: BigInt(0n),
        forDepositReward: BigInt(0n),
        spendTime: BigInt(0n),

        // input 'zAsset UTXOs'
        // to switch-off:
        //      1) utxoInAmount = 0
        //      2) utxoInSpendPrivKey = 0
        //      3) utxoInSpendKeyRandom = 0
        // switch-off control is used for:
        //      1) deposit only tx
        //      2) deposit & zAccount::zkpAmount
        //      3) deposit & zAccount::zkpAmount & withdraw
        //      4) deposit & withrdaw
        utxoInSpendPrivKey: [BigInt(0n), BigInt(0n)],
        utxoInSpendKeyRandom: [BigInt(0n), BigInt(0n)],
        utxoInAmount: [BigInt(0n), BigInt(0n)],
        utxoInOriginZoneId: [BigInt(0n), BigInt(0n)],
        utxoInOriginZoneIdOffset: [BigInt(0n), BigInt(0n)],
        utxoInOriginNetworkId: [BigInt(0n), BigInt(0n)],
        utxoInTargetNetworkId: [BigInt(0n), BigInt(0n)],
        utxoInCreateTime: [BigInt(0n), BigInt(0n)],
        utxoInZAccountId: [BigInt(0n), BigInt(0n)],
        utxoInMerkleTreeSelector: [
            [BigInt(0n), BigInt(0n)],
            [BigInt(0n), BigInt(0n)],
        ],
        utxoInPathIndex: [
            [
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
            ],
            [
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
            ],
        ],
        utxoInPathElements: [
            [
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
            ],
            [
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
            ],
        ],
        utxoInNullifier: [BigInt(0n), BigInt(0n)],

        // input 'zAccount UTXO'
        zAccountUtxoInId: BigInt(0n),
        zAccountUtxoInZkpAmount: BigInt(0n),
        zAccountUtxoInPrpAmount: BigInt(0n),
        zAccountUtxoInZoneId: BigInt(0n),
        zAccountUtxoInNetworkId: BigInt(0n),
        zAccountUtxoInExpiryTime: BigInt(0n),
        zAccountUtxoInNonce: BigInt(0n),
        zAccountUtxoInTotalAmountPerTimePeriod: BigInt(0n),
        zAccountUtxoInCreateTime: BigInt(0n),
        zAccountUtxoInRootSpendPubKey: [BigInt(0n), BigInt(0n)],
        zAccountUtxoInMasterEOA: BigInt(0n),
        zAccountUtxoInSpendPrivKey: BigInt(0n),
        zAccountUtxoInMerkleTreeSelector: [BigInt(0n), BigInt(0n)],
        zAccountUtxoInPathIndices: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zAccountUtxoInPathElements: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zAccountUtxoInNullifier: BigInt(0n),

        // blacklist merkle tree & proof of non-inclusion - zAccountId is the index-path
        zAccountBlackListLeaf: BigInt(0n),
        zAccountBlackListMerkleRoot: BigInt(0n),
        zAccountBlackListPathElements: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],

        // zAccountZoneRecord
        zZoneOriginZoneIDs: BigInt(0n),
        zZoneTargetZoneIDs: BigInt(0n),
        zZoneNetworkIDsBitMap: BigInt(0n),
        zZoneKycKytMerkleTreeLeafIDsAndRulesList: BigInt(0n),
        zZoneKycExpiryTime: BigInt(0n),
        zZoneKytExpiryTime: BigInt(0n),
        zZoneDepositMaxAmount: BigInt(0n),
        zZoneWithrawMaxAmount: BigInt(0n),
        zZoneInternalMaxAmount: BigInt(0n),
        zZoneMerkleRoot: BigInt(0n),
        zZonePathElements: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zZonePathIndex: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zZoneEdDsaPubKey: [BigInt(0n), BigInt(0n)],
        zZoneDataEscrowEphimeralRandom: BigInt(0n),
        zZoneDataEscrowEphimeralPubKeyAx: BigInt(0n),
        zZoneDataEscrowEphimeralPubKeyAy: [BigInt(1n)],
        zZoneZAccountIDsBlackList: BigInt(
            '1766847064778384329583297500742918515827483896875618958121606201292619775',
        ),
        zZoneMaximumAmountPerTimePeriod: BigInt(0n),
        zZoneTimePeriodPerMaximumAmount: BigInt(0n),
        zZoneDataEscrowEncryptedMessageAx: BigInt(0n),
        zZoneDataEscrowEncryptedMessageAy: BigInt(1n),

        // KYC-KYT
        // to switch-off:
        //      1) depositAmount = 0
        //      2) withdrawAmount = 0
        // switch-off control is used for internal tx
        kytEdDsaPubKey: [BigInt(0n), BigInt(0n)],
        kytEdDsaPubKeyExpiryTime: BigInt(0n),
        kycKytMerkleRoot: BigInt(0n),
        kytPathElements: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        kytPathIndex: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        kytMerkleTreeLeafIDsAndRulesOffset: BigInt(0n),
        kytDepositSignedMessagePackageType: BigInt(0n),
        kytDepositSignedMessageTimestamp: BigInt(0n),
        kytDepositSignedMessageSender: BigInt(0n),
        kytDepositSignedMessageReceiver: BigInt(0n),
        kytDepositSignedMessageToken: BigInt(0n),
        kytDepositSignedMessageSessionIdHex: BigInt(0n),
        kytDepositSignedMessageRuleId: BigInt(0n),
        kytDepositSignedMessageAmount: BigInt(0n),
        kytDepositSignedMessageHash: BigInt(0n),
        kytDepositSignature: [BigInt(0n), BigInt(0n), BigInt(0n)],
        kytWithdrawSignedMessagePackageType: BigInt(0n),
        kytWithdrawSignedMessageTimestamp: BigInt(0n),
        kytWithdrawSignedMessageSender: BigInt(0n),
        kytWithdrawSignedMessageReceiver: BigInt(0n),
        kytWithdrawSignedMessageToken: BigInt(0n),
        kytWithdrawSignedMessageSessionIdHex: BigInt(0n),
        kytWithdrawSignedMessageRuleId: BigInt(0n),
        kytWithdrawSignedMessageAmount: BigInt(0n),
        kytWithdrawSignedMessageHash: BigInt(0n),
        kytWithdrawSignature: [BigInt(0n), BigInt(0n), BigInt(0n)],

        // data escrow
        dataEscrowPubKey: [BigInt(0n), BigInt(0n)],
        dataEscrowPubKeyExpiryTime: BigInt(0n),
        dataEscrowEphimeralRandom: BigInt(0n),
        dataEscrowEphimeralPubKeyAx: BigInt(0n),
        dataEscrowEphimeralPubKeyAy: BigInt(1n),
        dataEscrowPathElements: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        dataEscrowPathIndex: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],

        // ------------- scalars-size --------------------------------
        // 1) 1 x 64 (zAsset)
        // 2) 1 x 64 (zAccountId << 16 | zAccountZoneId)
        // 3) nUtxoIn x 64 amount
        // 4) nUtxoOut x 64 amount
        // 5) MAX(nUtxoIn,nUtxoOut) x ( utxo-in-origin-zones-ids & utxo-out-target-zone-ids - 32 bit )
        // ------------- ec-points-size -------------
        // 1) nUtxoOut x SpendPubKeys (x,y) - (already a points on EC)

        dataEscrowEncryptedMessageAx: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        dataEscrowEncryptedMessageAy: [
            BigInt(1n),
            BigInt(1n),
            BigInt(1n),
            BigInt(1n),
            BigInt(1n),
            BigInt(1n),
            BigInt(1n),
            BigInt(1n),
            BigInt(1n),
            BigInt(1n),
        ],

        // dao data escrow
        daoDataEscrowPubKey: [BigInt(0n), BigInt(0n)],
        daoDataEscrowEphimeralRandom: BigInt(0n),
        daoDataEscrowEphimeralPubKeyAx: BigInt(0n),
        daoDataEscrowEphimeralPubKeyAy: BigInt(1n),

        // ------------- scalars-size --------------
        // 1) 1 x 64 (zAccountId << 16 | zAccountZoneId)
        // 2) MAX(nUtxoIn,nUtxoOut) x 64 ( utxoInOriginZoneId << 16 | utxoOutTargetZoneId)
        // ------------- ec-points-size -------------
        // 1) 0n
        daoDataEscrowEncryptedMessageAx: [BigInt(0n), BigInt(0n), BigInt(0n)],
        daoDataEscrowEncryptedMessageAy: [BigInt(1n), BigInt(1n), BigInt(1n)],

        // output 'zAsset UTXOs'
        // to switch-off:
        //      1) utxoOutAmount = 0n
        // switch-off control is used for
        //      1) withdraw only tx
        //      2) zAccount::zkpAmount & withdraw
        //      3) deposit & zAccount::zkpAmount & withdraw
        //      4) deposit & withdraw
        utxoOutCreateTime: BigInt(0n),
        utxoOutAmount: [BigInt(0n), BigInt(0n)],
        utxoOutOriginNetworkId: [BigInt(0n), BigInt(0n)],
        utxoOutTargetNetworkId: [BigInt(0n), BigInt(0n)],
        utxoOutTargetZoneId: [BigInt(0n), BigInt(0n)],
        utxoOutTargetZoneIdOffset: [BigInt(0n), BigInt(0n)],
        utxoOutSpendPubKeyRandom: [BigInt(0n), BigInt(0n)],
        utxoOutRootSpendPubKey: [
            [BigInt(0n), BigInt(0n)],
            [BigInt(0n), BigInt(0n)],
        ],
        utxoOutCommitment: [BigInt(0n), BigInt(0n)],

        // output 'zAccount UTXO'
        zAccountUtxoOutZkpAmount: BigInt(0n),
        zAccountUtxoOutSpendKeyRandom: BigInt(0n),
        zAccountUtxoOutCommitment: BigInt(0n),

        // output 'protocol + relayer fee in ZKP'
        chargedAmountZkp: BigInt(0n),

        // zNetworks tree
        // network parameters:
        // 1) is-active - 1 bit (circuit will set it to TRUE ALWAYS)
        // 2) network-id - 6 bit
        // 3) rewards params - all of them: forTxReward, forUtxoReward, forDepositReward
        // 4) daoDataEscrowPubKey[2]
        zNetworkId: BigInt(0n),
        zNetworkChainId: BigInt(0n),
        zNetworkIDsBitMap: BigInt(0n),
        zNetworkTreeMerkleRoot: BigInt(0n),
        zNetworkTreePathElements: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zNetworkTreePathIndex: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],

        // static tree merkle root
        // Poseidon of:
        // 1) zAssetMerkleRoot
        // 2) zAccountBlackListMerkleRoot
        // 3) zNetworkTreeMerkleRoot
        // 4) zZoneMerkleRoot
        // 5) kycKytMerkleRoot
        staticTreeMerkleRoot: BigInt(0n),
        forestMerkleRoot: BigInt(0n),
        taxiMerkleRoot: BigInt(0n),
        busMerkleRoot: BigInt(0n),
        ferryMerkleRoot: BigInt(0n),

        // salt
        salt: BigInt(0n),
        saltHash: BigInt(0n),

        // magical constraint - groth16 attack: https://geometry.xyz/notebook/groth16-malleability
        magicalConstraint: BigInt(0n),
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
        triadMerkleTree = new TriadMerkleTree(
            16,
            BigInt(
                '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d',
            ),
            poseidon2or3,
        );

        zAssetMerkleTree = new MerkleTree(poseidon2or3, 16, BigInt(0));
        zoneRecordMerkleTree = new MerkleTree(poseidon2or3, 16, BigInt(0));
        zAccountBlackListMerkleTree = new MerkleTree(
            poseidon2or3,
            16,
            BigInt(0),
        );
        kycKytMerkleTree = new MerkleTree(poseidon2or3, 16, BigInt(0));

        rootSenderKeys = deriveKeypairFromSeed(BigInt(0x0123456789abcdef));
        rootRecipientKeys = deriveKeypairFromSeed(BigInt(0x0123456789abcdef));
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

    it('Should compute valid full-proccess proof with deposit-input (w/o public-hash)', async () => {});

    it('Should compute valid full-proccess proof with withdraw-input (w/o public-hash)', async () => {});

    it('Should compute valid full-proccess proof with deposit-withdraw-input (w/o public-hash)', async () => {});

    it('Should compute valid full-proccess proof with masp-internal-input (w/o public-hash)', async () => {});

    it('Should compute valid full-proof', async () => {});
});
