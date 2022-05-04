chmod +x run_test.sh
# [0] - NoteHasher test - basic poseidon(2,3,5) hashes
./run_test.sh noteHasherTest.circom noteHasherTest.json 2>&1 | egrep "[SUCCESS|FAIL]"
./run_test.sh noteHasherTest.circom noteHasherTest_2.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [1] - Public key gen 
./run_test.sh babyPbkTest.circom babyPbkTest.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [2] - Spend proof - without nullifier & rewards - Tree-Depth 16 
./run_test.sh inclusionProverTest.circom inclusionProverTest.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [3] - Spend proof - without nullifier & rewards - Tree-Depth 15 ( as in Solidity )
./run_test.sh inclusionProverTest_2.circom inclusionProverTest_2.json 2>&1 | egrep "[SUCCESS|FAIL]"