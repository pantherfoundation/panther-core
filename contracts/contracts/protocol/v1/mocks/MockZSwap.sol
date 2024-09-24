// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
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

    function _getTokenTypeAndAddress(
        uint256 tokenTypeAndAddress
    ) external view returns (uint8 tokenType, address tokenAddress) {
        return tokenTypeAndAddress.getTokenTypeAndAddress();
    }
}
