// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../staking/interfaces/IFxStateSender.sol";

import "../TransferHelper.sol";

contract MockRootChainManager {
    address private immutable FX_ROOT;

    address private immutable CHILD_CHAIN_MANAGER;

    address public immutable ROOT_TOKEN;

    event FxDepositERC20(
        address indexed rootToken,
        address indexed depositor,
        address indexed userAddress,
        uint256 amount
    );

    constructor(
        address _fxRoot,
        address childChainManager,
        address _rootToken
    ) {
        require(
            _fxRoot != address(0) && _rootToken != address(0),
            "init:zero address"
        );

        FX_ROOT = _fxRoot;
        CHILD_CHAIN_MANAGER = childChainManager;
        ROOT_TOKEN = _rootToken;
    }

    function depositFor(
        address user,
        address rootToken,
        bytes calldata depositData
    ) external {
        uint256 amount = abi.decode(depositData, (uint256));

        TransferHelper.safeTransferFrom(
            ROOT_TOKEN,
            msg.sender, // depositor
            address(this), // manager contract
            amount
        );

        bytes memory message = abi.encode(user, amount);

        IFxStateSender(FX_ROOT).sendMessageToChild(
            CHILD_CHAIN_MANAGER,
            message
        );

        emit FxDepositERC20(rootToken, msg.sender, user, amount);
    }

    uint256[50] private __gap;
}
