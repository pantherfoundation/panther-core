// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma circom 2.0.0;

include "../../circuits/templates/merkleInclusionProofChecker.circom";

// non-linear constraints: 4820, linear constraints: 0
component main {public [leaf, root]} = MerkleInclusionProofChecker(20);
