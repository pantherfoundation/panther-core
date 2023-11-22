import * as path from 'path';

import circom_wasm_tester from 'circom_tester';
const wasm_tester = circom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {wtns} from 'snarkjs';

describe('ZAccount Registration - ZeroInput - Witness computation', async function (this: any) {
    let circuit: any;
    let mainZAccountRegistrationWasm: any;
    let mainZAccountRegistrationWitness: any;

    this.timeout(10000000);

    before(async () => {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './circuits/mainZAccountRegistrationV1.circom',
        );
        circuit = await wasm_tester(input, opts);

        mainZAccountRegistrationWasm = path.join(
            opts.basedir,
            './compiled/zAccountRegistration/circuits.wasm',
        );

        mainZAccountRegistrationWitness = path.join(
            opts.basedir,
            './compiled/generate_witness.js',
        );
    });

    const zeroInput = {
        // external data anchoring
        extraInputsHash: BigInt(0n),

        // zkp amounts (not scaled)
        zkpAmount: BigInt(0n),
        zkpChange: BigInt(0n),

        // zAsset
        zAssetId: BigInt(0n),
        zAssetToken: BigInt(0n),
        zAssetTokenId: BigInt(0n),
        zAssetNetwork: BigInt(0n),
        zAssetOffset: BigInt(0n),
        zAssetWeight: BigInt(0n),
        zAssetScale: BigInt(1n),
        zAssetMerkleRoot: BigInt(0n),
        zAssetPathIndices: [
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

        // zAccount
        zAccountId: BigInt(0n),
        zAccountZkpAmount: BigInt(0n),
        zAccountPrpAmount: BigInt(0n),
        zAccountZoneId: BigInt(0n),
        zAccountNetworkId: BigInt(0n),
        zAccountExpiryTime: BigInt(0n),
        zAccountNonce: BigInt(0n),
        zAccountTotalAmountPerTimePeriod: BigInt(0n),
        zAccountCreateTime: BigInt(0n),
        zAccountRootSpendPubKey: [BigInt(0n), BigInt(1n)],
        zAccountReadPubKey:[BigInt(0n), BigInt(1n)],
        zAccountNullifierPubKey:[BigInt(0n), BigInt(1n)],
        zAccountMasterEOA: BigInt(0n),
        zAccountRootSpendPrivKey: BigInt(0n),
        zAccountReadPrivKey:BigInt(0n),
        zAccountNullifierPrivKey:BigInt(0n),
        zAccountSpendKeyRandom: BigInt(0n),
        zAccountNullifier: BigInt(0n),
        zAccountCommitment: BigInt(0n),

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

        // zZone
        zZoneOriginZoneIDs: BigInt(0n),
        zZoneTargetZoneIDs: BigInt(0n),
        zZoneNetworkIDsBitMap: BigInt(0n),
        zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList: BigInt(0n),
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
        zZonePathIndices: [
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
        zZoneZAccountIDsBlackList: BigInt(
            '1766847064778384329583297500742918515827483896875618958121606201292619775',
        ),
        zZoneMaximumAmountPerTimePeriod: BigInt(0n),
        zZoneTimePeriodPerMaximumAmount: BigInt(0n),

        // KYC
        kycEdDsaPubKey: [BigInt(0n), BigInt(0n)],
        kycEdDsaPubKeyExpiryTime: BigInt(0n),
        trustProvidersMerkleRoot: BigInt(0n),
        kycPathElements: [
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
        kycPathIndices: [
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
        kycMerkleTreeLeafIDsAndRulesOffset: BigInt(0n),
        // signed message
        kycSignedMessagePackageType: BigInt(1n), // MUST be 1 - pkg type of KYC is always 1
        kycSignedMessageTimestamp: BigInt(0n),
        kycSignedMessageSender: BigInt(0n),
        kycSignedMessageReceiver: BigInt(0n),
        kycSignedMessageSessionId: BigInt(0n),
        kycSignedMessageRuleId: BigInt(0n),
        kycSignedMessageSigner: BigInt(0n),
        kycSignedMessageHash: BigInt(0n),
        kycSignature: [BigInt(0n), BigInt(0n), BigInt(0n)],

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
        zNetworkTreePathIndices: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        daoDataEscrowPubKey: [BigInt(0n), BigInt(0n)],
        forTxReward: BigInt(0n),
        forUtxoReward: BigInt(0n),
        forDepositReward: BigInt(0n),

        // static tree merkle root
        // Poseidon of:
        // 1) zAssetMerkleRoot
        // 2) zAccountBlackListMerkleRoot
        // 3) zNetworkTreeMerkleRoot
        // 4) zZoneMerkleRoot
        // 5) kycKytMerkleRoot
        staticTreeMerkleRoot: BigInt(0n),

        // forest root
        // Poseidon of:
        // 1) UTXO-Taxi-Tree   - 6 levels MT
        // 2) UTXO-Bus-Tree    - 26 levels MT
        // 3) UTXO-Ferry-Tree  - 6 + 26 = 32 levels MT (6 for 16 networks)
        // 4) Static-Tree
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

    it('should compute valid witness for zero input tx', async () => {
        await wtns.calculate(
            zeroInput,
            mainZAccountRegistrationWasm,
            mainZAccountRegistrationWitness,
            null,
        );
        console.log('Witness calculation successful!');
    });
});
