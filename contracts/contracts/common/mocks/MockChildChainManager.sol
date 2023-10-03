// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../interfaces/IPZkp.sol";

import "../../staking/interfaces/IFxStateSender.sol";
import "../ImmutableOwnable.sol";

import "../TransferHelper.sol";

contract MockChildChainManager is ImmutableOwnable {
    address public immutable FX_CHILD;

    address private immutable ROOT_CHAIN_MANAGER;

    address public immutable CHILD_TOKEN;

    event FxDepositERC20(
        address indexed rootToken,
        address indexed depositor,
        address indexed userAddress,
        uint256 amount
    );

    constructor(
        address _owner,
        address _fxChild,
        address _rootChainManager,
        address _childToken
    ) ImmutableOwnable(_owner) {
        require(
            _fxChild != address(0) && _rootChainManager != address(0),
            "init:zero address"
        );

        FX_CHILD = _fxChild;
        ROOT_CHAIN_MANAGER = _rootChainManager;
        CHILD_TOKEN = _childToken;
    }

    function processMessageFromRoot(
        uint256, // stateId (Polygon PoS Bridge state sync ID, unused)
        address rootMessageSender,
        bytes calldata content
    ) external {
        require(msg.sender == FX_CHILD, "PMR:INVALID_CALLER");
        require(rootMessageSender == ROOT_CHAIN_MANAGER, "PMR:INVALID_SENDER");

        (address to, uint256 amount) = abi.decode(content, (address, uint256));

        IPZkp(CHILD_TOKEN).deposit(to, abi.encode(amount));
    }

    function setPzkpMinter(address _minter) external onlyOwner {
        require(IPZkp(CHILD_TOKEN).minter() == address(this), "Unauthorized");

        IPZkp(CHILD_TOKEN).setMinter(_minter);
    }

    uint256[50] private __gap;
}
