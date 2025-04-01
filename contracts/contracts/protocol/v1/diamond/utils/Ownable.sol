// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import { LibDiamond } from "../libraries/LibDiamond.sol";

abstract contract Ownable {
    /// @dev Throws if called by any account other than the {OWNER}.
    modifier onlyOwner() virtual {
        LibDiamond.enforceOwner();
        _;
    }
}
