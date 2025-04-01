// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable one-contract-per-file
pragma solidity 0.8.19;

import "../core/facets/PrpVoucherController.sol";

/// @title MockPrpVoucherGrantor
/// @notice The only purpose of this contract  is unit testing of PRPGrantor
contract MockPrpVoucherController is PrpVoucherController {
    constructor(
        address pantherTrees,
        address feeMaster,
        address zkpToken
    ) PrpVoucherController(pantherTrees, feeMaster, zkpToken) {}

    modifier onlyOwner() virtual override {
        _;
    }

    function getPantherTreesAndFeeMasterAndZkpAddresses()
        external
        view
        returns (address pantherTrees, address feeMaster, address zkpToken)
    {
        return (PANTHER_TREES, FEE_MASTER, ZKP_TOKEN);
    }

    function verifyOrRevert(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) internal view virtual override {} // solhint-disable-line no-empty-blocks
}
