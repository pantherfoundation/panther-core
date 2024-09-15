// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./diamond/Diamond.sol";

contract PantherTrees is Diamond {
    constructor(
        address owner,
        address diamondCutFacet
    ) Diamond(owner, diamondCutFacet) {}
}
