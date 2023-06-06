#!/bin/bash
set -e

cd "$(dirname "$0")"
cd ..
pwd

zeroSeed="Pantherprotocol"
# Number of levels with nodes/leaves "below" the tree root
# Also defined in Constants.sol
treeDepth="31"

[ -d contracts/protocol/binaryTree/ ] || mkdir contracts/protocol/binaryTree/

node_modules/.bin/ts-node lib/binaryMerkleZerosContractGenerator.ts \
    ${zeroSeed} \
    ${treeDepth} \
    > contracts/protocol/binaryTree/BinaryMerkleZeros.sol
