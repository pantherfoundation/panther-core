import * as path from 'path';
import {wtns, groth16} from 'snarkjs';
import {getOptions} from './../helpers/circomTester';

const opts = getOptions();

const main_tx_wasm_file_path = path.join(
    opts.basedir,
    './compiled/mainTransaction_v1_extended_js/mainTransaction_v1_extended.wasm',
);

const main_tx_witness = path.join(
    opts.basedir,
    './compiled/mainTransaction_v1_extended',
);

const proving_key_path = path.join(
    opts.basedir,
    './compiled/mainTransaction_v1_extended_final.zkey',
);

const verification_key_path = path.join(
    opts.basedir,
    './compiled/mainTransaction_v1_extended_verification_key.json',
);

export const generateProof = async (input: {}) => {
    await wtns.calculate(input, main_tx_wasm_file_path, main_tx_witness, null);
    const prove = await groth16.prove(proving_key_path, main_tx_witness, null);

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
    //      3) utxoInRootSpendPrivKey = 0
    // switch-off control is used for:
    //      1) deposit only tx
    //      2) deposit & zAccount::zkpAmount
    //      3) deposit & zAccount::zkpAmount & withdraw
    //      4) deposit & withrdaw
    utxoInSpendPrivKey: [BigInt(0n), BigInt(0n)],
    utxoInRootSpendPrivKey: [BigInt(0n), BigInt(0n)],
    utxoInAmount: [BigInt(0n), BigInt(0n)],
    utxoInOriginZoneId: [BigInt(0n), BigInt(0n)],
    utxoInOriginZoneIdOffset: [BigInt(0n), BigInt(0n)],
    utxoInOriginNetworkId: [BigInt(0n), BigInt(0n)],
    utxoInTargetNetworkId: [BigInt(0n), BigInt(0n)],
    utxoInCreateTime: [BigInt(0n), BigInt(0n)],
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
    zoneRecordOriginZoneIDs: BigInt(0n),
    zoneRecordTargetZoneIDs: BigInt(0n),
    zoneRecordNetworkIDsBitMap: BigInt(0n),
    zoneRecordKycKytMerkleTreeLeafIDsAndRulesList: BigInt(0n),
    zoneRecordKycExpiryTime: BigInt(0n),
    zoneRecordKytExpiryTime: BigInt(0n),
    zoneRecordDepositMaxAmount: BigInt(0n),
    zoneRecordWithrawMaxAmount: BigInt(0n),
    zoneRecordInternalMaxAmount: BigInt(0n),
    zoneRecordMerkleRoot: BigInt(0n),
    zoneRecordPathElements: [
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
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
    zoneRecordPathIndex: [
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
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
    zoneRecordEdDsaPubKey: [BigInt(0n), BigInt(0n)],
    zoneRecordDataEscrowEphimeralRandom: BigInt(0n),
    zoneRecordDataEscrowEphimeralPubKeyAx: BigInt(0n),
    zoneRecordDataEscrowEphimeralPubKeyAy: [BigInt(1n)],
    zoneRecordZAccountIDsBlackList: BigInt(
        '1766847064778384329583297500742918515827483896875618958121606201292619775',
    ),
    zoneRecordMaximumAmountPerTimePeriod: BigInt(0n),
    zoneRecordTimePeriodPerMaximumAmount: BigInt(0n),
    zoneRecordDataEscrowEncryptedMessageAx: BigInt(0n),
    zoneRecordDataEscrowEncryptedMessageAy: BigInt(1n),

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
    // 4) zoneRecordMerkleRoot
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
