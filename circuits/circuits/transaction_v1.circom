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

template TransactionV1(nUtxoIn, nUtxoOut, UtxoMerkleTreeDepth, WeightMerkleTreeDepth) {

    signal input publicInputsHash; // single explicitly public

    signal input extraInputsHash; // public - sha256 hash of: depositAddress, withdrawalAddress, plugin.ContractAddress, secrets ( cipherText not needed )

    signal input publicToken; // public; address from `token` for a deposit/withdraw, zero otherwise
    signal input extAmountIn; // public; in token units, non-zero for a deposit
    signal input extAmountOut; // public; in token units, non-zero for a withdrawal

    signal input token;

    // weight
    signal input weightMerkleRoot; // public
    signal input weightLeaf; // 160b token, 32b weight, at most 8b path indexes
    signal input weightPathElements[WeightMerkleTreeDepth+1]; // extra slot for the third leave

    // reward computation params
    signal input forTxReward; // public
    signal input forUtxoReward; // public
    signal input forDepositReward; // public

    // input 'token UTXOs'
    signal input spendTime; // public
    // UTXOs
    signal input spendPrivKeys[nUtxoIn];
    signal input leaves[nUtxoIn]; // 120b amount, 32b create time, 24b tree-number, Depth-bits for index
    signal input merkleRoots[nUtxoIn]; // public
    signal input nullifiers[nUtxoIn]; // public
    signal input pathElements[nUtxoIn][UtxoMerkleTreeDepth+1]; // extra slot for the third leave

    // input 'reward UTXO'
    signal input rLeaf; // 64b amount, 24b tree-number, Depth bits for index
    signal input rSpendPrivKey;
    signal input rCommitmentIn;
    signal input rMerkleRoot; // public
    signal input rNullifier; // public
    signal input rNonceIn; // 64 bit
    signal input rPathElements[UtxoMerkleTreeDepth+1];

    // for both 'token' and 'reward' output UTXOs
    signal input createTime; // public;

    // output 'token UTXOs'
    // real leaf - 120b amount, 32b createTime, 24b treeNumber, 16b indexes
    // this info is encrypted by creator of Output UTXO and logged on-chain in order to use it later when one need to spend
    // spendPrivKey known to owner of this UTXO_output
    signal input amountsOut[nUtxoOut]; // in token units
    signal input spendPubKeys[nUtxoOut][2];
    signal input commitmentsOut[nUtxoOut]; // public - Poseidon(5) hash of spendPubKeys, amountOut, token, createTime

    // output 'reward UTXO'
    signal input rAmountOut; // in reward units
    signal input rPubKeyOut[2];
    signal input rNonceOut; // 64 bit - test to be rNonceIn + 1 == rNonceOut
    signal input rCommitmentOut; // public

    // output 'relayer reward'
    signal input relayerAmountTips; // in reward units
    signal input relayerRewardCipherText[4]; // public [c1, c2] - c1{Ax,Ay}, c2{Ax,Ay} - we need it unpacked since we use it for computation that need unpacked - but in public hash we will use it as packed version
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
    rewards.rAmountTips <== relayerAmountTips;
    rewards.spendTime <== spendTime;
    rewards.assetWeight <== weightChk.weight;

    var totalAmountIn = extAmountIn; // in token units

    for(var i=0; i<nUtxoIn; i++){
        // decode leaf
        leafDecoders[i] = UtxoLeafDecoder(UtxoMerkleTreeDepth);
        leafDecoders[i].leaf <== leaves[i];

        // verify nullifier - know all parameters to hash Poseidon(2)
        nullifierHashers[i] = NullifierHasher();
        nullifierHashers[i].spendPrivKey <== spendPrivKeys[i];
        nullifierHashers[i].leaf <== leaves[i];
        nullifierHashers[i].out === nullifiers[i];

        // derive spending pubkey
        inputPubKeys[i] = BabyPbk();
        inputPubKeys[i].in <== spendPrivKeys[i];

        // compute commitment
        inputNoteHashers[i] = NoteHasherPacked();
        inputNoteHashers[i].spendPk[0] <== inputPubKeys[i].Ax;
        inputNoteHashers[i].spendPk[1] <== inputPubKeys[i].Ay;
        inputNoteHashers[i].amount <== leafDecoders[i].amount;
        inputNoteHashers[i].token <== token;
        inputNoteHashers[i].createTime <== leafDecoders[i].createTime;

        // verify Merkle proofs for input notes
        inclusionProvers[i] = NoteInclusionProver(UtxoMerkleTreeDepth);
        // This is leaf in MerkleTree - Poseidon(3) hash of pubKey{Ax,Ay}, packed ( amount, token, createTime )
        inclusionProvers[i].note <== inputNoteHashers[i].out;
        for(var j=0; j< UtxoMerkleTreeDepth+1; j++) {
            inclusionProvers[i].pathElements[j] <== pathElements[i][j];
            inclusionProvers[i].pathIndices[j] <== leafDecoders[i].index[j];
        }
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
        outputNoteHashers[i] = NoteHasherPacked();
        outputNoteHashers[i].spendPk[0] <== spendPubKeys[i][0]; // Poseidon.Ax
        outputNoteHashers[i].spendPk[1] <== spendPubKeys[i][1]; // Poseidon.Ay
        outputNoteHashers[i].amount <== amountsOut[i];
        outputNoteHashers[i].token <== token;
        outputNoteHashers[i].createTime <== createTime;

        // Proof that Poseidon(3) hash is equal to provided precomputed hash of same params, last 3 params are packed
        outputNoteHashers[i].out === commitmentsOut[i];

        // accumulate total
        totalAmountOut += amountsOut[i];
    }

    // 4. Check if amounts of input and output 'token UTXOs' equal
    totalAmountOut === totalAmountIn;

    // 5. Verify input 'reward UTXO'
    component rewardDecoder = RewardLeafDecoder(UtxoMerkleTreeDepth);
    rewardDecoder.leaf <== rLeaf;
    component rewardInHasher = RNoteHasherPacked();
    component rPubKeyIn = BabyPbk();
    rPubKeyIn.in <== rSpendPrivKey;
    rewardInHasher.spendPk[0] <== rPubKeyIn.Ax;
    rewardInHasher.spendPk[1] <== rPubKeyIn.Ay;
    rewardInHasher.amount <== rewardDecoder.amount;
    rewardInHasher.nonce <== rNonceIn;
    rewardInHasher.out === rCommitmentIn;

    // verify reward nullifier
    component rewardNullifierHasher = NullifierHasher();
    rewardNullifierHasher.spendPrivKey <== rSpendPrivKey;
    rewardNullifierHasher.leaf <== rLeaf;
    rewardNullifierHasher.out === rNullifier;

    // verify reward membership
    component rewardMerkleVerifier = MerkleTreeInclusionProof(UtxoMerkleTreeDepth);
    rewardMerkleVerifier.leaf <== rCommitmentIn;
    for(var i=0; i<UtxoMerkleTreeDepth+1; i++) {
        rewardMerkleVerifier.pathIndices[i] <== rewardDecoder.index[i];
        rewardMerkleVerifier.pathElements[i] <== rPathElements[i];
    }
    rewardMerkleVerifier.root === rMerkleRoot;

    // 6. Verify output 'reward UTXO'
    rAmountOut === rewardDecoder.amount + rewards.rAmount;

    // commitment
    component rewardOutHasher = RNoteHasherPacked();
    rewardOutHasher.spendPk[0] <== rPubKeyOut[0];
    rewardOutHasher.spendPk[1] <== rPubKeyOut[1];
    rewardOutHasher.amount <== rAmountOut;
    rewardOutHasher.nonce <== rNonceOut;
    rewardOutHasher.out === rCommitmentOut;

    // 7. Verify 'relayer reward' ciphertext
    component elgamalEncryption = ElGamalEncryption();
    elgamalEncryption.r <== relayerRandomness;
    elgamalEncryption.m <== relayerAmountTips;
    elgamalEncryption.Y[0] <== relayerPK[0];
    elgamalEncryption.Y[1] <== relayerPK[1];
    elgamalEncryption.c1[0] === relayerRewardCipherText[0];
    elgamalEncryption.c1[1] === relayerRewardCipherText[1];
    elgamalEncryption.c2[0] === relayerRewardCipherText[2];
    elgamalEncryption.c2[1] === relayerRewardCipherText[3];

    // 8. Verify rNonceIn + 1 == rNonceOut
    rNonceOut === rNonceIn + 1;

    // 9. Check `publicToken`
    component publicTokenChecker = PublicTokenChecker();
    publicTokenChecker.publicToken <== publicToken;
    publicTokenChecker.token <== token;
    publicTokenChecker.extAmounts <== extAmountIn + extAmountOut;

    // Verify "public" input signals
    // TOTAL inputs ~ 256 + 160 + 2*96 + 256 + 3*40 + 32 + 256 + 256 + 32 + 4*256 + 2*256 + 2*256 + 2*24 + 2*256 = not more ! 4096 bit
    // desirable for Polygon is 15x256 since Poseidon(5) is max in Solidity so 3 * Poseidon(5)
    // ACCEPTED - packed version of relayerRewardCipherText ( for public hasher input only )
    component publicInputHasher = PublicInputHasherTripplePoseidon(nUtxoIn, nUtxoOut); // PublicInputHasher
    publicInputHasher.extraInputsHash <== extraInputsHash; // keccak256 is 256 bits
    publicInputHasher.publicToken <== publicToken; // 160 bit
    publicInputHasher.extAmountIn <== extAmountIn; // 64 bit
    publicInputHasher.extAmountOut <== extAmountOut; // 64 bit
    publicInputHasher.weightMerkleRoot <== weightMerkleRoot; // 256 bit cause of poseidon(5)
    publicInputHasher.forTxReward <== forTxReward; // 40 bit
    publicInputHasher.forUtxoReward <== forUtxoReward; // 40 bit
    publicInputHasher.forDepositReward <== forDepositReward; // 40 bit
    publicInputHasher.spendTime <== spendTime; // 32 bit
    publicInputHasher.rMerkleRoot <== rMerkleRoot; // 256 bit
    publicInputHasher.rNullifier <== rNullifier; // 256 bit since Poseidon(3) hash
    publicInputHasher.createTime <== createTime; // 32 bit
    for (var i=0; i<4; i++)
        publicInputHasher.relayerRewardCipherText[i] <== relayerRewardCipherText[i]; // 254 bit - ElGamal BabyPbk - Lets pack it for hash to be 256+1 bit - Ax, Sign
    for (var i=0; i<nUtxoIn; i++) {
        publicInputHasher.merkleRoots[i] <== merkleRoots[i]; // 256 bit
        publicInputHasher.nullifiers[i] <== nullifiers[i]; // 256 bit
        publicInputHasher.treeNumbers[i] <== leafDecoders[i].treeNumber; // 24 bit
    }
    for (var i=0; i<nUtxoOut; i++)
        publicInputHasher.commitmentsOut[i] <== commitmentsOut[i]; // 256 bit since hashing

    publicInputHasher.out === publicInputsHash; // 256 bit since hashing
}
