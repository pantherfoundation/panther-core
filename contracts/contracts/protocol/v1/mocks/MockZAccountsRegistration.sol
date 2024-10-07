// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../core/facets/ZAccountsRegistration.sol";

contract MockZAccountsRegistration is ZAccountsRegistration {
    uint256 public nextId;

    address public owner;

    constructor(
        uint8 _zAccountVersion,
        address prpVoucherGrantor,
        address pantherTrees,
        address feeMaster,
        address zkpToken
    )
        ZAccountsRegistration(
            _zAccountVersion,
            prpVoucherGrantor,
            pantherTrees,
            feeMaster,
            zkpToken
        )
    {
        owner = msg.sender;
    }

    function mockZAccountIdTracker(uint256 _zAccountIdTracker) external {
        zAccountIdTracker = _zAccountIdTracker;
    }

    function internalGetNextZAccountId() external {
        nextId = _getNextZAccountId();
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

    function updateMaxTimeOffset(uint32 _maxBlockTimeOffset) public {
        maxBlockTimeOffset = _maxBlockTimeOffset;
    }

    function getSelfAndPantherTreeAddr()
        external
        view
        returns (address self, address pantherTree)
    {
        return (SELF, PANTHER_TREES);
    }

    function internalFeeMasterDebt(
        address token
    ) external view returns (uint256) {
        return feeMasterDebt[token];
    }
}
