#!/bin/bash
set -e

cd "$(dirname "$0")"
cd ..

# The nothing-up-my-sleeve value
maciNums="8370432830353022751713833565135785980866757267633941821328460903436894336785"

# Binary tree with zero = maciNums
node_modules/.bin/ts-node lib/genZerosContract.ts \
    MerkleBinaryMaci $maciNums 33 "Binary tree zeros (Keccack hash of 'Maci')" \
    > contracts/MerkleBinaryMaci.sol
