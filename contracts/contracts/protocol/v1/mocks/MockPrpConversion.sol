// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../core/facets/PrpConversion.sol";
import "../../../common/Claimable.sol";

contract MockPrpConversion is PrpConversion, Claimable {
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

    function testWithdrawZkp(
        address token,
        address to,
        uint256 amount
    ) external {
        _claimErc20(token, to, amount);
    }
}
