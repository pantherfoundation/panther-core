// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../core/facets/ZSwap.sol";
import "../core/libraries/TokenTypeAndAddressDecoder.sol";

contract MockZSwap is ZSwap {
    using TokenTypeAndAddressDecoder for uint256;
    address public owner;

    constructor(
        address pantherTrees,
        address vault,
        address feeMaster,
        address zkpToken
    ) ZSwap(pantherTrees, vault, feeMaster, zkpToken) {
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

    function internalGetTokenTypeAndAddress(
        uint256 tokenTypeAndAddress
    ) external pure returns (uint8 tokenType, address tokenAddress) {
        return tokenTypeAndAddress.getTokenTypeAndAddress();
    }

    function getPantherTreeAndVaultAddr()
        external
        view
        returns (address pantherTree, address vault)
    {
        return (PANTHER_TREES, VAULT);
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
