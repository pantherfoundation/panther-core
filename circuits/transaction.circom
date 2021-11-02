//SPDX-License-Identifier: ISC
pragma circom 2.0.0;
include "./templates/rewards.circom";
include "./templates/elgamalEncryption.circom";
include "./templates/noteHasher.circom";
include "./templates/noteInclusionProver.circom";
include "./templates/nullifierHasher.circom";
include "./templates/publicInputHasher.circom";
include "./templates/publicTokenChecker.circom";
include "./templates/rNoteHasher.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

// spendPubKey := BabyPubKey(spendPrivKey)
// Leaf := Poseidon(spendPubKey, amount, token, createTime)
// Nullifier := Poseidon(spendPrivKey, leafId)
// tokenWeightLeaf := addr||weight  160 + 12, Merkle tree of depth 7

template Transaction(nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth, WeightMerkleTreeDepth) {

    signal input publicInputsHash; // single explicitly public

    signal input extraInputsHash; // public

    signal input publicToken; // public; address from `token` for a deposit/withdraw, zero otherwise
    signal input extAmountIn; // public; in token units, non-zero for a deposit
    signal input extAmountOut; // public; in token units, non-zero for a withdrawal

    // token
    signal input token; // first 12-bits for weight, then 20-bits for address
    signal input tokenMerkleRoot; // public
    signal input tokenPathIndices;
    signal input tokenPathElements[WeightMerkleTreeDepth+1]; // extra slot for the third leave

    // reward computation params
    signal input forTxReward; // public
    signal input forUtxoReward; // public
    signal input forDepositReward; // public

    // input 'token UTXOs'
    signal input spendTime; // public
    // UTXOs
    signal input amountsIn[nUtxoIn]; // in token units
    signal input spendPrivKeys[nUtxoIn];
    signal input leafIds[nUtxoIn];
    signal input merkleRoots[nUtxoIn]; // public
    signal input nullifiers[nUtxoIn]; // public
    signal input pathIndices[nUtxoIn];
    signal input pathElements[nUtxoIn][UtxoMerkleTreeDepth+1]; // extra slot for the third leave
    signal input createTimes[nUtxoIn];

    // input 'reward UTXO'
    signal input rAmountIn; // in reward units
    signal input rSpendPrivKey;
    signal input rCommitmentIn;
    signal input rMerkleRoot; // public
    signal input rNullifier; // public
    signal input rPathIndices;
    signal input rPathElements[UtxoMerkleTreeDepth+1];

    // for both 'token' and 'reward' output UTXOs
    signal input createTime; // public;

    // output 'token UTXOs'
    signal input amountsOut[nUtxoOut]; // in token units
    signal input spendPubKeys[nUtxoOut][2];
    signal input commitmentsOut[nUtxoOut]; // public

    // output 'reward UTXO'
    signal input rAmountOut; // in reward units
    // TODO: analize if a new reward SpedKey required
    signal input rCommitmentOut; // public

    // output 'relayer reward'
    signal input rAmountTips; // in reward units
    signal input relayerRewardCipherText[4]; // public [c1, c2]
    signal input relayerPK[2];
    signal input relayerRandomness;




    /* Total amounts bellow can not overflow since:
      - capped `nUtxoIn` and `nUtxoOut` limit number of additions
      - `LimitChecker` caps output UTXO amounts and, indirectly, input amounts
      - smart contract caps `extAmountIn` and `extAmountOut` */

    // 1. Verify "public" input signals

    // TODO: tightly pack "public" input signals to optimize hashing
    component publicInputHasher = PublicInputHasher(nUtxoIn, nUtxoOut);
    publicInputHasher.extraInputsHash <== extraInputsHash;
    publicInputHasher.publicToken <== publicToken;
    publicInputHasher.extAmountIn <== extAmountIn;
    publicInputHasher.extAmountOut <== extAmountOut;
    publicInputHasher.tokenMerkleRoot <== tokenMerkleRoot;
    publicInputHasher.forTxReward <== forTxReward;
    publicInputHasher.forUtxoReward <== forUtxoReward;
    publicInputHasher.forDepositReward <== forDepositReward;
    publicInputHasher.spendTime <== spendTime;
    publicInputHasher.rMerkleRoot <== rMerkleRoot;
    publicInputHasher.rNullifier <== rNullifier;
    publicInputHasher.createTime <== createTime;
    for (var i=0; i<4; i++)
        publicInputHasher.relayerRewardCipherText[i] <== relayerRewardCipherText[i];
    for (var i=0; i<nUtxoIn; i++) {
        publicInputHasher.merkleRoots[i] <== merkleRoots[i];
        publicInputHasher.nullifiers[i] <== nullifiers[i];
    }
    for (var i=0; i<nUtxoOut; i++)
        publicInputHasher.commitmentsOut[i] <== commitmentsOut[i];

    publicInputHasher.out === publicInputsHash;

    // 2. Verify notes and compute total amount of input 'token UTXOs'
    // .. and prepare computation of rewards

    component nullifierHashers[nUtxoIn];
    component pubKeys[nUtxoIn];
    component inputNoteHashers[nUtxoIn];
    component inclusionProvers[nUtxoIn];
    component rewards = Rewards(nUtxoIn);

    // pass values for computing rewards
    rewards.extAmountIn <== extAmountIn;
    rewards.forTxReward <== forTxReward;
    rewards.forUtxoReward <== forUtxoReward;
    rewards.forDepositReward <== forDepositReward;
    rewards.rAmountTips <== rAmountTips;
    rewards.spendTime <== spendTime;

    // bitify `token`
    component n2b = Num2Bits_strict();
    n2b.in <== token;
    // get first 12 bits as tokenWeight
    component b2nWeight = Bits2Num(12);
    for(var i=0; i<12; i++)
        b2nWeight.in[i] <== n2b.out[i];
    rewards.assetWeight <== b2nWeight.out;
    // then get 20 bits as tokenAddress
    component b2nTokenAddress = Bits2Num(20);
    for(var i=0; i<20; i++)
        b2nTokenAddress.in[i] <== n2b.out[i+12];
    signal tokenAddress;
    tokenAddress <== b2nTokenAddress.out;

    // verify Merkle proof for token weight
    component merkleWeightInclusionProof = MerkleTreeInclusionProof(WeightMerkleTreeDepth);
    merkleWeightInclusionProof.leaf <== token;
    merkleWeightInclusionProof.pathIndices <== tokenPathIndices;
    for(var i=0; i<=WeightMerkleTreeDepth; i++)
        merkleWeightInclusionProof.pathElements[i] <== tokenPathElements[i];
    merkleWeightInclusionProof.root === tokenMerkleRoot;

    var totalAmountIn = extAmountIn; // in token units

    for(var i=0; i<nUtxoIn; i++){

        // verify nullifier
        nullifierHashers[i] = NullifierHasher();
        nullifierHashers[i].spendPrivKey <== spendPrivKeys[i];
        nullifierHashers[i].leafId <== leafIds[i];
        nullifierHashers[i].out === nullifiers[i];

        // derive spending pubkey
        pubKeys[i] = BabyPbk();
        pubKeys[i].in <== spendPrivKeys[i];

        // compute commitment
        inputNoteHashers[i] = NoteHasher();
        inputNoteHashers[i].spendPk[0] <== pubKeys[i].Ax;
        inputNoteHashers[i].spendPk[1] <== pubKeys[i].Ay;
        inputNoteHashers[i].amount <== amountsIn[i];
        inputNoteHashers[i].token <== tokenAddress;
        inputNoteHashers[i].createTime <== createTimes[i];

        // verify Merkle proof with non-zero amounts
        inclusionProvers[i] = NoteInclusionProver(UtxoMerkleTreeDepth);
        inclusionProvers[i].leaf <== inputNoteHashers[i].out;
        inclusionProvers[i].pathIndices <== pathIndices[i];
        for(var j=0; j<= UtxoMerkleTreeDepth; j++)
            inclusionProvers[i].pathElements[j] <== pathElements[i][j];
        inclusionProvers[i].root <== merkleRoots[i];
        inclusionProvers[i].utxoAmount <== amountsIn[i];

        // pass value for computing rewards
        rewards.createTimes[i] <== createTimes[i];
        rewards.amountsIn[i] <== amountsIn[i];

        // accumulate total
        totalAmountIn += amountsIn[i];
    }


    // 3. Verify notes and compute total amount of output 'token UTXOs'

    component outputNoteHashers[nUtxoOut];

    var totalAmountOut = extAmountOut;

    for(var i=0; i<nUtxoOut; i++){

        // verify commitment
        outputNoteHashers[i] = NoteHasher();
        outputNoteHashers[i].spendPk[0] <== spendPubKeys[i][0];
        outputNoteHashers[i].spendPk[1] <== spendPubKeys[i][1];
        outputNoteHashers[i].amount <== amountsOut[i];
        outputNoteHashers[i].token <== tokenAddress;
        outputNoteHashers[i].createTime <== createTime;
        outputNoteHashers[i].out === commitmentsOut[i];

        // accumulate total
        totalAmountOut += amountsOut[i];
    }

    // 4. Check if amounts of input and output 'token UTXOs' equal
    totalAmountOut === totalAmountIn;

    // 5. Verify input 'reward UTXO'

    // commitment
    component rewardInHasher = RNoteHasher();
    component rSpendPubKeys = BabyPbk();
    rSpendPubKeys.in <== rSpendPrivKey;
    rewardInHasher.spendPk[0] <== rSpendPubKeys.Ax;
    rewardInHasher.spendPk[1] <== rSpendPubKeys.Ay;
    rewardInHasher.amount <== rAmountIn;
    rewardInHasher.out === rCommitmentIn;

    // nullifier
    component rewardNullifierHasher = NullifierHasher();
    rewardNullifierHasher.spendPrivKey <== rSpendPrivKey;
    rewardNullifierHasher.leafId <== rPathIndices;
    rewardNullifierHasher.out === rNullifier;

    // 6. Verify output 'reward UTXO'

    // amount
    rAmountOut === rAmountIn + rewards.rAmount;

    // commitment
    component rewardOutHasher = Poseidon(3);
    rewardOutHasher.inputs[0] <== rSpendPubKeys.Ax;
    rewardOutHasher.inputs[1] <== rSpendPubKeys.Ay;
    rewardOutHasher.inputs[2] <== rAmountOut;
    rewardOutHasher.out === rCommitmentOut;

    // 7. Verify 'relayer reward' ciphertext
    component elgamalEncryption = ElGamalEncryption();
    elgamalEncryption.r <== relayerRandomness;
    elgamalEncryption.m <== rAmountTips;
    elgamalEncryption.Y[0] <== relayerPK[0];
    elgamalEncryption.Y[1] <== relayerPK[1];
    elgamalEncryption.c1[0] === relayerRewardCipherText[0];
    elgamalEncryption.c1[1] === relayerRewardCipherText[1];
    elgamalEncryption.c2[0] === relayerRewardCipherText[2];
    elgamalEncryption.c2[1] === relayerRewardCipherText[3];

    // 8. Check `publicToken`
    component publicTokenChecker = PublicTokenChecker();
    publicTokenChecker.publicToken <== publicToken;
    publicTokenChecker.tokenAddress <== tokenAddress;
    publicTokenChecker.extAmounts <== extAmountIn + extAmountOut;
}
