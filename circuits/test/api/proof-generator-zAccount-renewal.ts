import * as path from 'path';
import {wtns, groth16} from 'snarkjs';
import {getOptions} from '../helpers/circomTester';

const opts = getOptions();

const zAccount_renewal_wasm_file_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_renewal_v1_js/main_zAccount_renewal_v1.wasm',
);

const zAccount_renewal_witness = path.join(
    opts.basedir,
    './compiled/main_zAccount_renewal_v1_js/generate_witness.js',
);

const proving_key_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_renewal_v1_extended_final.zkey',
);

const verification_key_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_renewal_v1_extended_verification_key.json',
);

export const generateProof = async (input: {}) => {
    await wtns.calculate(
        input,
        zAccount_renewal_wasm_file_path,
        zAccount_renewal_witness,
        null,
    );
    const prove = await groth16.prove(
        proving_key_path,
        zAccount_renewal_witness,
        null,
    );

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
// Input data for different type of tx (deposit, withdraw, internal tx)
let data = {};

const zeroInputForZAccountRenewal = {
    extraInputsHash: BigInt(0n),
    chargedAmountZkp: BigInt(0n),

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

    zAccountUtxoInRootSpendPrivKey: BigInt(0n),
    zAccountUtxoInRootSpendPubKey: [BigInt(0n), BigInt(1n)],
    zAccountUtxoInSpendKeyRandom: BigInt(0n),

    zAccountUtxoInMasterEOA: BigInt(0n),
    zAccountUtxoInId: BigInt(0n),
    zAccountUtxoInZkpAmount: BigInt(0n),
    zAccountUtxoInPrpAmount: BigInt(0n),
    zAccountUtxoInZoneId: BigInt(0n),
    zAccountUtxoInExpiryTime: BigInt(0n),
    zAccountUtxoInNonce: BigInt(0n),
    zAccountUtxoInTotalAmountPerTimePeriod: BigInt(0n),
    zAccountUtxoInCreateTime: BigInt(0n),
    zAccountUtxoInNetworkId: BigInt(0n),

    zNetworkId: BigInt(0n),
    zAccountUtxoInCommitment: BigInt(0n),

    zAccountUtxoInNullifier: BigInt(0n),
    zAccountUtxoOutZkpAmount: BigInt(0n),
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

    zAccountUtxoOutSpendKeyRandom: BigInt(0n),
    zAccountUtxoOutExpiryTime: BigInt(0n),
    zAccountUtxoOutCreateTime: BigInt(0n),

    zZoneKycExpiryTime: BigInt(0n),
    zAccountUtxoOutCommitment: BigInt(0n),

    kycSignedMessagePackageType: BigInt(0n),
    kycSignedMessageTimestamp: BigInt(0n),
    kycSignedMessageSender: BigInt(0n),
    kycSignedMessageReceiver: BigInt(0n),
    kycSignedMessageToken: BigInt(0n),
    kycSignedMessageSessionIdHex: BigInt(0n),
    kycSignedMessageRuleId: BigInt(0n),
    kycSignedMessageAmount: BigInt(0n),

    kycKytMerkleRoot: BigInt(0n),
    kycEdDsaPubKey: [BigInt(0n), BigInt(1n)],
    kycSignature: [BigInt(0n), BigInt(0n), BigInt(0n)],
    kycSignedMessageHash: BigInt(0n),
    kycEdDsaPubKeyExpiryTime: BigInt(0n),

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
    kycPathIndex: [
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
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
    zZoneKycKytMerkleTreeLeafIDsAndRulesList: BigInt(0n),
    kycMerkleTreeLeafIDsAndRulesOffset: BigInt(0n),

    zZoneEdDsaPubKey: [BigInt(0n), BigInt(1n)],
    zZoneOriginZoneIDs: BigInt(0n),
    zZoneTargetZoneIDs: BigInt(0n),
    zZoneNetworkIDsBitMap: BigInt(0n),
    zZoneKytExpiryTime: BigInt(0n),
    zZoneDepositMaxAmount: BigInt(0n),
    zZoneWithrawMaxAmount: BigInt(0n),
    zZoneInternalMaxAmount: BigInt(0n),
    zZoneZAccountIDsBlackList:
        BigInt(
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        ),
    zZoneMaximumAmountPerTimePeriod: BigInt(0n),
    zZoneTimePeriodPerMaximumAmount: BigInt(0n),

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
    zNetworkChainId: BigInt(0n),
    zNetworkIDsBitMap: BigInt(0n),
    forTxReward: BigInt(0n),
    forUtxoReward: BigInt(0n),
    forDepositReward: BigInt(0n),

    daoDataEscrowPubKey: [BigInt(0n), BigInt(1n)],
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

    zZoneMerkleRoot: BigInt(0n),
    staticTreeMerkleRoot: BigInt(0n),

    forestMerkleRoot: BigInt(0n),
    taxiMerkleRoot: BigInt(0n),
    busMerkleRoot: BigInt(0n),
    ferryMerkleRoot: BigInt(0n),

    salt: BigInt(0n),
    saltHash: BigInt(0n),
    magicalConstraint: BigInt(0n),
};

// zero input
data = zeroInputForZAccountRenewal;

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
