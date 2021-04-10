// SPDX-License-Identifier: ISC

include "./templates/limitChecker.circom";
include "./templates/noteHasher.circom";
include "./templates/noteInclusionProver.circom";
include "./templates/nullifierHasher.circom";
include "./templates/publicInputHasher.circom";
include "./templates/publicTokenChecker.circom";
include "../node_modules/circomlib/circuits/babyjub.circom";

// spendPubKey := BabyPubKey(spendPrivKey)
// Leaf := Poseidon(spendPubKey.Ax, spendPubKey.Ay, amount, token, createTime)
// Nullifier := Poseidon(spendPrivKey, leafId)
// TODO: account for "token weight"

template Transaction(nUtxoIn, nUtxoOut, nRwdUtxoOut, MerkleTreeDepth) {
    assert(nUtxoIn <= 16);
    assert(nUtxoOut + nRwdUtxoOut <= 16);
    assert(nRwdUtxoOut > 0);

    signal input publicInputsHash; // single explicitly public

    signal private input publicToken; // public; `token` for a deposit/withdraw, zero otherwise
    signal private input extAmountIn; // public; non-zero for a deposit
    signal private input extAmountOut; // public; non-zero for a withdrawal
    signal private input token;
    signal private input rewardToken; // public
    signal private input forTxReward; // public
    signal private input forUtxoReward; // public
    signal private input forDepositReward; // public
    signal private input extraInputsHash; // public

    // input `token` UTXOs (i.e. notes being spent)
    signal private input spendTime; // public
    // all UTXOs are token UTXOs (no reward points UTXOs)
    signal private input amountsIn[nUtxoIn];
    signal private input spendPrivKeys[nUtxoIn];
    signal private input leafIds[nUtxoIn];
    signal private input merkleRoots[nUtxoIn]; // public
    signal private input nullifiers[nUtxoIn]; // public
    signal private input pathIndices[nUtxoIn];
    signal private input pathElements[nUtxoIn][MerkleTreeDepth];
    signal private input createTimes[nUtxoIn];

    // output `token` UTXOs (i.e. notes being created)
    signal private input createTime; // public; both for `token` and `rewardToken` notes
    signal private input amountsOut[nUtxoOut];
    signal private input spendPubKeys[nUtxoOut][2];
    signal private input commitmentsOut[nUtxoOut]; // public

    // output `rewardToken` UTXOs (i.e. notes being created)
    signal private input rAmountsOut[nRwdUtxoOut];
    signal private input rSpendPubKeys[nRwdUtxoOut][2];
    signal private input rCommitmentsOut[nRwdUtxoOut]; // public


    /* Total amounts bellow can not overflow since:
      - capped `nUtxoIn`, `nUtxoOut` and `nRwdUtxoOut` limit number of additions
      - `LimitChecker` caps output UTXO amounts and, indirectly, input amounts
      - smart contract caps `extAmountIn` and `extAmountOut` */

    // 1. Verify "public" input signals

    component publicInputHasher = PublicInputHasher(nUtxoIn, nUtxoOut, nRwdUtxoOut);

    publicInputHasher.publicToken <== publicToken;
    publicInputHasher.extAmountIn <== extAmountIn;
    publicInputHasher.extAmountOut <== extAmountOut;
    publicInputHasher.rewardToken <== rewardToken;
    publicInputHasher.forTxReward <== forTxReward;
    publicInputHasher.forUtxoReward <== forUtxoReward;
    publicInputHasher.forDepositReward <== forDepositReward;
    publicInputHasher.extraInputsHash <== extraInputsHash;
    publicInputHasher.spendTime <== spendTime;
    publicInputHasher.createTime <== createTime;
    for (var i=0; i<nUtxoIn; i++)
        publicInputHasher.merkleRoots[i] <== merkleRoots[i];
    for (var i=0; i<nUtxoOut; i++)
        publicInputHasher.commitmentsOut[i] <== commitmentsOut[i];
    for (var i=0; i<nRwdUtxoOut; i++)
        publicInputHasher.rCommitmentsOut[i] <== rCommitmentsOut[i];

    publicInputHasher.out === publicInputsHash;


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
