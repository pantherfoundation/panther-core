//SPDX-License-Identifier: ISC
pragma circom 2.0.0;
include "./templates/rewards.circom";
include "./templates/elgamalEncryption.circom";
include "./templates/noteHasher.circom";
include "./templates/noteInclusionProver.circom";
include "./templates/nullifierHasher.circom";
include "./templates/publicInputHasher.circom";
include "./templates/publicTokenChecker.circom";
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

    signal input publicToken; // public; `token` for a deposit/withdraw, zero otherwise
    signal input extAmountIn; // public; non-zero for a deposit
    signal input extAmountOut; // public; non-zero for a withdrawal

    // token
    signal input token; // first 12-bits for weight, then 20-bits for token address
    signal input tokenMerkleRoot; // public
    signal input tokenPathIndices;
    signal input tokenPathElements[WeightMerkleTreeDepth+1]; // extra slot for the third leave

    // reward points
    signal input forTxReward; // public
    signal input forUtxoReward; // public
    signal input forDepositReward; // public
    signal input relayerTips;

    // input `token` UTXOs (i.e. notes being spent)
    signal input spendTime; // public
    // token UTXOs
    signal input amountsIn[nUtxoIn];
    signal input spendPrivKeys[nUtxoIn];
    signal input leafIds[nUtxoIn];
    signal input merkleRoots[nUtxoIn]; // public
    signal input nullifiers[nUtxoIn]; // public
    signal input pathIndices[nUtxoIn];
    signal input pathElements[nUtxoIn][UtxoMerkleTreeDepth+1]; // extra slot for the third leave
    signal input createTimes[nUtxoIn];

    // input user reward UTXO
    signal input rAmountIn;
    signal input rSpendPrivKey;
    signal input rCommitmentIn;
    signal input rMerkleRoot; // public
    signal input rNullifier; // public
    signal input rPathIndices;
    signal input rPathElements[UtxoMerkleTreeDepth+1];


    // output token UTXOs
    signal input createTime; // public; both for `token` and `rewardToken` notes
    signal input amountsOut[nUtxoOut];
    signal input spendPubKeys[nUtxoOut][2];
    signal input commitmentsOut[nUtxoOut]; // public 

    // output user reward UTXO
    signal input rAmountOut;
    signal input rCommitmentsOut; // public

    // output relayer reward ciphertext
    signal input relayerRewardCipherText[4]; // public [c1, c2]
    signal input relayerPK[2];
    signal input relayerRandomness;




    /* Total amounts bellow can not overflow since:
      - capped `nUtxoIn`, `nUtxoOut` and `nRwdUtxoOut` limit number of additions
      - `LimitChecker` caps output UTXO amounts and, indirectly, input amounts
      - smart contract caps `extAmountIn` and `extAmountOut` */

    // // 1. Verify "public" input signals

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


    // 2. Verify input notes, compute total amount (in `token`) of spent UTXOs, ..
    // .. and compute total amount (in `rewardToken`) of applicable rewards

    component nullifierHashers[nUtxoIn];
    component pubKeys[nUtxoIn];
    component inputNoteHashers[nUtxoIn];
    component inclusionProvers[nUtxoIn];
    component rewards = Rewards(nUtxoIn);

    // compute rewards over input utxos
    rewards.extAmountIn <== extAmountIn;
    rewards.forTxReward <== forTxReward;
    rewards.forUtxoReward <== forUtxoReward;
    rewards.forDepositReward <== forDepositReward;
    rewards.relayerTips <== relayerTips;
    rewards.spendTime <== spendTime;

    // bitify token
    component n2b = Num2Bits_strict();
    n2b.in <== token;
    // get first 12 bits as tokenWeight
    component b2nWeight = Bits2Num(12);
    for(var i=0; i<12; i++)
        b2nWeight.in[i] <== n2b.out[i];
    rewards.assetWeight <== b2nWeight.out;
    // then get 20 bits as tokenWeight
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

    var totalAmountIn = extAmountIn; // in `token`

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


    // 3. Verify output `token` notes, ..
    // .. and compute total amount (in `token`) of created UTXOs

    component outputNoteHashers[nUtxoOut];

    var totalAmountOut = extAmountOut; // in `token`

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


    // 4. Check if input and output UTXO amounts (in `token`) equal
    totalAmountOut === totalAmountIn;

    // verify input reward commitment
    component rewardInHasher = Poseidon(3);
    component rewardInPbk = BabyPbk();
    rewardInPbk.in <== rSpendPrivKey;
    rewardInHasher.inputs[0] <== rewardInPbk.Ax;
    rewardInHasher.inputs[1] <== rewardInPbk.Ay;
    rewardInHasher.inputs[2] <== rAmountIn;
    rewardInHasher.out === rCommitmentIn;

    // verify input reward nullifier
    component rewardNullifierHasher = NullifierHasher();
    rewardNullifierHasher.spendPrivKey <== rSpendPrivKey;
    rewardNullifierHasher.leafId <== rPathIndices;
    rewardNullifierHasher.out === rNullifier;

    // verify output reward
    rAmountOut === rAmountIn + rewards.userRewards;

    // verify output reward
    component rewardOutHasher = Poseidon(3);
    rewardOutHasher.inputs[0] <== rewardInPbk.Ax;
    rewardOutHasher.inputs[1] <== rewardInPbk.Ay;
    rewardOutHasher.inputs[2] <== rAmountOut;
    rewardOutHasher.out === rCommitmentsOut;

    // verify relayers tips ciphertext
    component elgamalEncryption = ElGamalEncryption();
    elgamalEncryption.r <== relayerRandomness;
    elgamalEncryption.m <== relayerTips;
    elgamalEncryption.Y[0] <== relayerPK[0];
    elgamalEncryption.Y[1] <== relayerPK[1];
    elgamalEncryption.c1[0] === relayerRewardCipherText[0];
    elgamalEncryption.c1[1] === relayerRewardCipherText[1];
    elgamalEncryption.c2[0] === relayerRewardCipherText[2];
    elgamalEncryption.c2[1] === relayerRewardCipherText[3];

    // 7. Check `publicToken`
    component publicTokenChecker = PublicTokenChecker();
    publicTokenChecker.publicToken <== publicToken;
    publicTokenChecker.token <== tokenAddress;
    publicTokenChecker.extAmounts <== extAmountIn + extAmountOut;
}