// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../core/facets/PrpConversion.sol";

contract MockPrpConversion is PrpConversion {
    address public owner;

    constructor(
        address pantherTrees,
        address vault,
        address feeMaster,
        address zkpToken
    ) PrpConversion(vault, pantherTrees, feeMaster, zkpToken) {
        owner = msg.sender;
    }

    function verifyOrRevert(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) internal view override {} // solhint-disable-line no-empty-blocks

    modifier onlyOwner() override {
        require(msg.sender == owner, "LibDiamond: Must be contract owner");
        _;
    }

    function getPantherTree() external view returns (address) {
        return PANTHER_TREES;
    }

    function internalIsSpent(
        uint256 nullifier
    ) external view returns (uint256) {
        return isSpent[bytes32(nullifier)];
    }

    function internalFeeMasterDebt(
        address token
    ) external view returns (uint256) {
        return feeMasterDebt[token];
    }
}
