// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "./diamond/Diamond.sol";

contract PantherTrees is Diamond {
    constructor(
        address owner,
        address diamondCutFacet
    ) Diamond(owner, diamondCutFacet) {}
}
