import * as path from 'path';
import {wtns, groth16} from 'snarkjs';
import {getOptions} from '../helpers/circomTester';

const opts = getOptions();

const amm_wasm_file_path = path.join(
    opts.basedir,
    './compiled/main_amm_v1_js/main_amm_v1.wasm',
);

const amm_witness = path.join(
    opts.basedir,
    './compiled/main_amm_v1_js/generate_witness.js',
);

const proving_key_path = path.join(opts.basedir, './compiled/amm_final.zkey');

const verification_key_path = path.join(
    opts.basedir,
    './compiled/amm_verification_key.json',
);

export const generateProof = async (input: {}) => {
    await wtns.calculate(input, amm_wasm_file_path, amm_witness, null);
    const prove = await groth16.prove(proving_key_path, amm_witness, null);

    const proof = prove.proof;
    const publicSignals = prove.publicSignals;

    return {proof, publicSignals};
};

export const verifyProof = async (proof: any, publicSignals: any) => {
    const verificationKeyJSON = require(verification_key_path);
    const verifyResult = await groth16.verify(
        verificationKeyJSON,
        publicSignals,
        proof,
        null,
    );

    if (verifyResult === true) {
        return 'Proof Verified!';
    } else {
        return 'Invalid Proof!!';
    }
};

// =========================USAGE FROM DAPP SIDE======================================
let data = {};

const zeroInput = {
    // external data anchoring
    extraInputsHash: BigInt(0n),

    chargedAmountZkp: BigInt(0n),
    createTime: BigInt(0n),
    depositAmountPrp: BigInt(0n),
    withdrawAmountPrp: BigInt(0n),

    utxoCommitment: BigInt(0n),
    utxoSpendPubKey: [BigInt(0n), BigInt(1n)],
    utxoSpendKeyRandom: BigInt(0n),

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

    zAccountUtxoInId: BigInt(0n),
    zAccountUtxoInZkpAmount: BigInt(0n),
    zAccountUtxoInPrpAmount: BigInt(0n),
    zAccountUtxoInZoneId: BigInt(0n),
    zAccountUtxoInNetworkId: BigInt(0n),
    zAccountUtxoInExpiryTime: BigInt(0n),
    zAccountUtxoInNonce: BigInt(0n),
    zAccountUtxoInTotalAmountPerTimePeriod: BigInt(0n),
    zAccountUtxoInCreateTime: BigInt(0n),
    zAccountUtxoInRootSpendPubKey: [BigInt(0n), BigInt(1n)],
    zAccountUtxoInSpendPrivKey: BigInt(0n),
    zAccountUtxoInMasterEOA: BigInt(0n),
    zAccountUtxoInSpendKeyRandom: BigInt(0n),
    zAccountUtxoInCommitment: BigInt(0n),
    zAccountUtxoInNullifier: BigInt(0n),

    zAccountUtxoOutZkpAmount: BigInt(0n),
    zAccountUtxoOutPrpAmount: BigInt(0n),
    zAccountUtxoOutSpendKeyRandom: BigInt(0n),
    zAccountUtxoOutCommitment: BigInt(0n),

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
    zZoneZAccountIDsBlackList: BigInt(
        '1766847064778384329583297500742918515827483896875618958121606201292619775',
    ),
    zZoneMaximumAmountPerTimePeriod: BigInt(0n),
    zZoneTimePeriodPerMaximumAmount: BigInt(0n),

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
    daoDataEscrowPubKey: [BigInt(0n), BigInt(0n)],
    forTxReward: BigInt(0n),
    forUtxoReward: BigInt(0n),
    forDepositReward: BigInt(0n),

    kycKytMerkleRoot: BigInt(0n),
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

// zero input
data = zeroInput;

async function main() {
    // Generate proof
    const {proof, publicSignals} = await generateProof(data);
    // console.log('proof=>', proof);
    // console.log('publicSignals=>', publicSignals);

    // Verify the generated proof
    console.log(await verifyProof(proof, publicSignals));
}

// Uncomment to generate proof
// main();
