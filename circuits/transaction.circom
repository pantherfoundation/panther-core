//SPDX-License-Identifier: ISC
pragma circom 2.0.0;

include "./templates/elgamalEncryption.circom";
include "./templates/noteHasher.circom";
include "./templates/noteInclusionProver.circom";
include "./templates/nullifierHasher.circom";
include "./templates/publicInputHasher.circom";
include "./templates/publicTokenChecker.circom";
include "../node_modules/circomlib/circuits/babyjub.circom";

// spendPubKey := BabyPubKey(spendPrivKey)
// Leaf := Poseidon(spendPubKey.Ax, amount, token, createTime)
// Nullifier := Poseidon(spendPrivKey, leafId)
// tokenWeightLeaf := addr||weight  160 + 12, Merkle tree of depth 7

template Transaction(nUtxoIn, nUtxoOut, MerkleTreeDepth) {

    signal input publicInputsHash; // single explicitly public

    signal input publicToken; // public; `token` for a deposit/withdraw, zero otherwise
    signal input extAmountIn; // public; non-zero for a deposit
    signal input extAmountOut; // public; non-zero for a withdrawal
    signal input token;
    signal input rewardToken; // public
    signal input forTxReward; // public
    signal input forUtxoReward; // public
    signal input forDepositReward; // public
    signal input forBaseReward; // public base relayer reward
    signal input extraInputsHash; // public

    // input `token` UTXOs (i.e. notes being spent)
    signal input spendTime; // public
    // token UTXOs
    signal input amountsIn[nUtxoIn];
    signal input spendPrivKeys[nUtxoIn];
    signal input leafIds[nUtxoIn];
    signal input merkleRoots[nUtxoIn]; // public
    signal input nullifiers[nUtxoIn]; // public
    signal input pathIndices[nUtxoIn];
    signal input pathElements[nUtxoIn][MerkleTreeDepth];
    signal input createTimes[nUtxoIn];

    // input user reward UTXO
    signal input rAmountIn;
    signal input rSpendPrivKey;
    signal input rCommitmentIn; // public
    signal input rMerkleRoot;
    signal input rNullifier;
    signal input rPathIndices;
    signal input rPathElements[MerkleTreeDepth];


    // output token UTXOs
    signal input createTime; // public; both for `token` and `rewardToken` notes
    signal input amountsOut[nUtxoOut];
    signal input spendPubKeys[nUtxoOut]; // x coordinates
    signal input commitmentsOut[nUtxoOut]; // public 

    // output user reward UTXO
    signal input rAmountOut;
    signal input rSpendPubKey; // x coordinate
    signal input rCommitmentsOut; // public

    // output relayer reward ciphertext
    signal input relayerRewardCipherText[4]; // public [c1, c2]


    /* Total amounts bellow can not overflow since:
      - capped `nUtxoIn`, `nUtxoOut` and `nRwdUtxoOut` limit number of additions
      - `LimitChecker` caps output UTXO amounts and, indirectly, input amounts
      - smart contract caps `extAmountIn` and `extAmountOut` */

    // // 1. Verify "public" input signals

    // component publicInputHasher = PublicInputHasher(nUtxoIn, nUtxoOut);

    // publicInputHasher.publicToken <== publicToken;
    // publicInputHasher.extAmountIn <== extAmountIn;
    // publicInputHasher.extAmountOut <== extAmountOut;
    // publicInputHasher.rewardToken <== rewardToken;
    // publicInputHasher.forTxReward <== forTxReward;
    // publicInputHasher.forUtxoReward <== forUtxoReward;
    // publicInputHasher.forDepositReward <== forDepositReward;
    // publicInputHasher.extraInputsHash <== extraInputsHash;
    // publicInputHasher.spendTime <== spendTime;
    // publicInputHasher.createTime <== createTime;
    // for (var i=0; i<nUtxoIn; i++)
    //     publicInputHasher.merkleRoots[i] <== merkleRoots[i];
    // for (var i=0; i<nUtxoOut; i++)
    //     publicInputHasher.commitmentsOut[i] <== commitmentsOut[i];
    // for (var i=0; i<nRwdUtxoOut; i++)
    //     publicInputHasher.rCommitmentsOut[i] <== rCommitmentsOut[i];

    // publicInputHasher.out === publicInputsHash;


    // 2. Verify input notes, compute total amount (in `token`) of spent UTXOs, ..
    // .. and compute total amount (in `rewardToken`) of applicable rewards

    component nullifierHashers[nUtxoIn];
    component pubKeys[nUtxoIn];
    component inputNoteHashers[nUtxoIn];
    component inclusionProvers[nUtxoIn];

    var totalAmountIn = extAmountIn; // in `token`
    // TODO: check (and add comment) if (why) rewardsExpected can't overflow
    var rewardsExpected = forTxReward + forDepositReward * extAmountIn; // in `rewardToken`

    for(var i=0; i<nUtxoIn; i++){

        // verify nullifier
        nullifierHashers[i] = NullifierHasher();
        nullifierHashers[i].spendPrivKey <== spendPrivKeys[i];
        nullifierHashers[i].leafId <== leafIds[i];
        nullifierHashers[i].out === nullifiers[i];

        // derive spending pubkey
        pubKeys[i] = BabyPbk();
        pubKeys[i].in <== spendPrivKeys[i]

        // compute commitment
        inputNoteHashers[i] = NoteHasher();
        inputNoteHashers[i].spendPbkX <== pubKeys[i].Ax; // to act as a blinding factor ..
        inputNoteHashers[i].spendPbkY <== pubKeys[i].Ay; // .. it shall be unique per UTXO
        inputNoteHashers[i].amount <== amountsIn[i];
        inputNoteHashers[i].token <== token;
        inputNoteHashers[i].createTime <== createTimes[i];

        // verify Merkle proof with non-zero amounts
        inclusionProvers[i] = NoteInclusionProver(MerkleTreeDepth);
        inclusionProvers[i].leaf <== inputNoteHashers[i].out;
        inclusionProvers[i].pathIndices <== pathIndices[i];
        for(var j=0; j< MerkleTreeDepth; j++)
            inclusionProvers[i].pathElements[j] <== pathElements[i][j];
        inclusionProvers[i].root <== merkleRoots[i];
        inclusionProvers[i].utxoAmount <== amountsIn[i];
        inclusionProvers[i].out === 1;

        // accumulate total
        totalAmountIn += amountsIn[i];

        // FIXME: make `ageFactor` be zero if `createTimes[i] > spendTime`
        var ageFactor = forUtxoReward * (spendTime - createTimes[i]);
        rewardsExpected += amountsIn[i] * ageFactor;
    }


    // 3. Verify output `token` notes, ..
    // .. and compute total amount (in `token`) of created UTXOs

    component limitCheckers[nUtxoOut];
    component outputNoteHashers[nUtxoOut];

    var totalAmountOut = extAmountOut; // in `token`

    for(var i=0; i<nUtxoOut; i++){
        // verify amount is within limit
        limitCheckers[i] = LimitChecker();
        limitCheckers[i].value <== amountsOut[i];
        limitCheckers[i].out === 1;

        // verify commitment
        outputNoteHashers[i] = NoteHasher();
        outputNoteHashers[i].spendPbkX <== spendPubKeys[i][0];
        outputNoteHashers[i].spendPbkY <== spendPubKeys[i][1];
        outputNoteHashers[i].amount <== amountsOut[i];
        outputNoteHashers[i].token <== token;
        outputNoteHashers[i].createTime <== createTime;
        outputNoteHashers[i].out === commitmentsOut[i];

        // accumulate total
        totalAmountOut += amountsOut[i];
    }


    // 4. Check if input and output UTXO amounts (in `token`) equal
    totalAmountOut === totalAmountIn;


    // 5. Verify output `rewardToken` notes, and ..
    // .. compute total amount in `rewardToken` of created UTXOs

    component rLimitCheckers[nRwdUtxoOut];
    component rOutputNoteHashers[nRwdUtxoOut];

    var totalRewardsOut = 0; // in `rewardToken`

    for(var i=0; i<nRwdUtxoOut; i++){
        // verify amount is within limit
        rLimitCheckers[i] = LimitChecker();
        rLimitCheckers[i].value <== rAmountsOut[i];
        rLimitCheckers[i].out === 1;

        // verify commitment
        rOutputNoteHashers[i] = NoteHasher();
        rOutputNoteHashers[i].spendPbkX <== rSpendPubKeys[i][0];
        rOutputNoteHashers[i].spendPbkY <== rSpendPubKeys[i][1];
        rOutputNoteHashers[i].amount <== rAmountsOut[i];
        rOutputNoteHashers[i].token <== rewardToken;
        rOutputNoteHashers[i].createTime <== createTime;
        rOutputNoteHashers[i].out === rCommitmentsOut[i];

        // accumulate total
        totalRewardsOut += rAmountsOut[i];
    }


    // 6. Check total amount of `rewardToken` UTXOs
    signal rewards; // intermediate signal
    rewards <-- rewardsExpected;
    rewards === totalRewardsOut;


    // 7. Check `publicToken`
    component publicTokenChecker = PublicTokenChecker();
    publicTokenChecker.publicToken <== publicToken;
    publicTokenChecker.token <== token;
    publicTokenChecker.extAmounts <== extAmountIn + extAmountOut;
    publicTokenChecker.out === 1;
}
