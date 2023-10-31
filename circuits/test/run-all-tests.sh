#!/bin/bash
chmod +x run-test.sh
# [0] - NoteHasher test - basic poseidon(2,3,5) hashes
./run-test.sh circuits/noteHasherTest.circom data/noteHasherTest.json 2>&1 | egrep "[SUCCESS|FAIL]"
./run-test.sh circuits/noteHasherTest.circom data/noteHasherTest2.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [1] - Public key gen
./run-test.sh circuits/babyPbkTest.circom data/babyPbkTest.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [2] - Spend proof - without nullifier & rewards - Tree-Depth 16
./run-test.sh circuits/inclusionProverTest.circom data/inclusionProverTest.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [3] - Spend proof - without nullifier & rewards - Tree-Depth 15 ( as in Solidity )
./run-test.sh circuits/inclusionProverTest_2.circom data/inclusionProverTest2.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [4] - Spend proof - without nullifier & rewards - Tree-Depth 15 ( as in Solidity )
./run-test.sh circuits/inclusionProverTest_2.circom data/inclusionProverTest3.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [4] - Spend proof - without nullifier & rewards - Tree-Depth 15 ( as in Solidity )
./run-test.sh circuits/inclusionProverTest_2.circom data/inclusionProverTest4.json 2>&1 | egrep "[SUCCESS|FAIL]"

# [5] - Long test - 50k commitmets
if [[ -z "$RUN_LONG_TESTS" ]]; then
    echo 'Skipped by default - Run it with `export RUN_LONG_TESTS=yes`'
else
    chmod +x run-test-parallel.sh
    # Untar
    tar -xf data/circom-jsons-1654702950656.tar.gz
    # Run long test
    ./run-test-parallel.sh circuits/inclusionProverTest_2.circom circom_jsons_1654702950656 2>&1 | egrep "[SUCCESS|FAIL]"
    # Delete
    rm -rf circom_jsons_1654702950656
fi
