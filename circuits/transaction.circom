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
include "./templates/utxoLeafDecoder.circom";
include "./templates/rewardLeafDecoder.circom";
include "./templates/weightChecker.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

// spendPubKey := BabyPubKey(spendPrivKey)
// Note := Poseidon(spendPubKey, amount, token, createTime)
// Nullifier := Poseidon(spendPrivKey, leaf)

template Transaction(nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth, WeightMerkleTreeDepth) {

    signal input publicInputsHash; // single explicitly public

    signal input extraInputsHash; // public

    signal input publicToken; // public; address from `token` for a deposit/withdraw, zero otherwise
    signal input extAmountIn; // public; in token units, non-zero for a deposit
    signal input extAmountOut; // public; in token units, non-zero for a withdrawal

    signal input token;

    // weight    
    signal input weightMerkleRoot; // public
    signal input weightLeaf; 
    signal input weightPathElements[WeightMerkleTreeDepth+1]; // extra slot for the third leave

    // reward computation params
    signal input forTxReward; // public
    signal input forUtxoReward; // public
    signal input forDepositReward; // public

    // input 'token UTXOs'
    signal input spendTime; // public
    // UTXOs
    signal input spendPrivKeys[nUtxoIn];
    signal input leaves[nUtxoIn];
    signal input merkleRoots[nUtxoIn]; // public
    signal input nullifiers[nUtxoIn]; // public
    signal input pathElements[nUtxoIn][UtxoMerkleTreeDepth+1]; // extra slot for the third leave

    // input 'reward UTXO'
    signal input rLeaf;
    signal input rSpendPrivKey;
    signal input rCommitmentIn;
    signal input rMerkleRoot; // public
    signal input rNullifier; // public
    signal input rPathElements[UtxoMerkleTreeDepth+1];

    // for both 'token' and 'reward' output UTXOs
    signal input createTime; // public;

    // output 'token UTXOs'
    signal input amountsOut[nUtxoOut]; // in token units
    signal input spendPubKeys[nUtxoOut][2];
    signal input commitmentsOut[nUtxoOut]; // public

    // output 'reward UTXO'
    signal input rAmountOut; // in reward units
    signal input rPubKeyOut[2];
    signal input rCommitmentOut; // public

    // output 'relayer reward'
    signal input rAmountTips; // in reward units
    signal input relayerRewardCipherText[4]; // public [c1, c2]
    signal input relayerPK[2];
    signal input relayerRandomness;

    // 1. Verify token's membership and decode its weight
    component weightChk = WeightChecker(WeightMerkleTreeDepth);
    weightChk.leaf <== weightLeaf;
    weightChk.token <== token;
    weightChk.merkleRoot <== weightMerkleRoot;
    for(var i=0; i<= WeightMerkleTreeDepth; i++)
        weightChk.pathElements[i] <== weightPathElements[i];
    
    // 2. Verify input notes, membership, compute total amount of input 'token UTXOs' and rewards
    component nullifierHashers[nUtxoIn];
    component inputPubKeys[nUtxoIn];
    component inputNoteHashers[nUtxoIn];
    component leafDecoders[nUtxoIn];
    component inclusionProvers[nUtxoIn];
    
    // pass values for computing rewards
    component rewards = Rewards(nUtxoIn);
    rewards.extAmountIn <== extAmountIn;
    rewards.forTxReward <== forTxReward;
    rewards.forUtxoReward <== forUtxoReward;
    rewards.forDepositReward <== forDepositReward;
    rewards.rAmountTips <== rAmountTips;
    rewards.spendTime <== spendTime;
    rewards.assetWeight <== weightChk.weight;

    var totalAmountIn = extAmountIn; // in token units

    for(var i=0; i<nUtxoIn; i++){
        // decode leaf
        leafDecoders[i] = UtxoLeafDecoder(UtxoMerkleTreeDepth);
        leafDecoders[i].leaf <== leaves[i];

        // verify nullifier
        nullifierHashers[i] = NullifierHasher();
        nullifierHashers[i].spendPrivKey <== spendPrivKeys[i];
        nullifierHashers[i].leaf <== leaves[i];
        nullifierHashers[i].out === nullifiers[i];

        // derive spending pubkey
        inputPubKeys[i] = BabyPbk();
        inputPubKeys[i].in <== spendPrivKeys[i];

        // compute commitment
        inputNoteHashers[i] = NoteHasher();
        inputNoteHashers[i].spendPk[0] <== inputPubKeys[i].Ax;
        inputNoteHashers[i].spendPk[1] <== inputPubKeys[i].Ay;
        inputNoteHashers[i].amount <== leafDecoders[i].amount;
        inputNoteHashers[i].token <== token;
        inputNoteHashers[i].createTime <== leafDecoders[i].createTime;

        // verify Merkle proofs for input notes
        inclusionProvers[i] = NoteInclusionProver(UtxoMerkleTreeDepth);
        inclusionProvers[i].note <== inputNoteHashers[i].out;
        for(var j=0; j< UtxoMerkleTreeDepth; j++) {
            inclusionProvers[i].pathElements[j] <== pathElements[i][j];
            inclusionProvers[i].pathIndices[j] <== leafDecoders[i].index[j];
        }
        inclusionProvers[i].pathElements[UtxoMerkleTreeDepth] <== pathElements[i][UtxoMerkleTreeDepth];
        inclusionProvers[i].root <== merkleRoots[i];
        inclusionProvers[i].utxoAmount <== leafDecoders[i].amount;

        // pass value for computing rewards
        rewards.createTimes[i] <== leafDecoders[i].createTime;
        rewards.amountsIn[i] <== leafDecoders[i].amount;

        // accumulate total
        totalAmountIn += leafDecoders[i].amount;
    }


    // 3. Verify output notes and compute total amount of output 'token UTXOs'

    component outputNoteHashers[nUtxoOut];

    var totalAmountOut = extAmountOut;

    for(var i=0; i<nUtxoOut; i++){

        // verify commitment
        outputNoteHashers[i] = NoteHasher();
        outputNoteHashers[i].spendPk[0] <== spendPubKeys[i][0];
        outputNoteHashers[i].spendPk[1] <== spendPubKeys[i][1];
        outputNoteHashers[i].amount <== amountsOut[i];
        outputNoteHashers[i].token <== token;
        outputNoteHashers[i].createTime <== createTime;
        outputNoteHashers[i].out === commitmentsOut[i];

        // accumulate total
        totalAmountOut += amountsOut[i];
    }

    // 4. Check if amounts of input and output 'token UTXOs' equal
    totalAmountOut === totalAmountIn;

    // 5. Verify input 'reward UTXO'
    component rewardDecoder = RewardLeafDecoder(UtxoMerkleTreeDepth);
    rewardDecoder.leaf <== rLeaf;
    component rewardInHasher = RNoteHasher();
    component rPubKeyIn = BabyPbk();
    rPubKeyIn.in <== rSpendPrivKey;
    rewardInHasher.spendPk[0] <== rPubKeyIn.Ax;
    rewardInHasher.spendPk[1] <== rPubKeyIn.Ay;
    rewardInHasher.amount <== rewardDecoder.amount;
    rewardInHasher.out === rCommitmentIn;

    // verify reward nullifier
    component rewardNullifierHasher = NullifierHasher();
    rewardNullifierHasher.spendPrivKey <== rSpendPrivKey;
    rewardNullifierHasher.leaf <== rLeaf;
    rewardNullifierHasher.out === rNullifier;

    // verify reward membership
    component rewardMerkleVerifier = MerkleTreeInclusionProof(UtxoMerkleTreeDepth);
    rewardMerkleVerifier.leaf <== rCommitmentIn;    
    for(var i=0; i<UtxoMerkleTreeDepth; i++) {
        rewardMerkleVerifier.pathIndices[i] <== rewardDecoder.index[i];
        rewardMerkleVerifier.pathElements[i] <== rPathElements[i];
    }
    rewardMerkleVerifier.pathElements[UtxoMerkleTreeDepth] <== rPathElements[UtxoMerkleTreeDepth];
    rewardMerkleVerifier.root === rMerkleRoot;

    // 6. Verify output 'reward UTXO'
    rAmountOut === rewardDecoder.amount + rewards.rAmount;

    // commitment
    component rewardOutHasher = RNoteHasher();
    rewardOutHasher.spendPk[0] <== rPubKeyOut[0];
    rewardOutHasher.spendPk[1] <== rPubKeyOut[1];
    rewardOutHasher.amount <== rAmountOut;
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
    publicTokenChecker.token <== token;
    publicTokenChecker.extAmounts <== extAmountIn + extAmountOut;

    // Verify "public" input signals

    // TODO: tightly pack "public" input signals to optimize hashing
    component publicInputHasher = PublicInputHasher(nUtxoIn, nUtxoOut);
    publicInputHasher.extraInputsHash <== extraInputsHash;
    publicInputHasher.publicToken <== publicToken;
    publicInputHasher.extAmountIn <== extAmountIn;
    publicInputHasher.extAmountOut <== extAmountOut;
    publicInputHasher.weightMerkleRoot <== weightMerkleRoot;
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
        publicInputHasher.treeNumbers[i] <== leafDecoders[i].treeNumber;
    }
    for (var i=0; i<nUtxoOut; i++)
        publicInputHasher.commitmentsOut[i] <== commitmentsOut[i];

    publicInputHasher.out === publicInputsHash;
}
