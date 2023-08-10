// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TransferHelper.sol";
import "../ImmutableOwnable.sol";

import "../../staking/interfaces/IFxStateSender.sol";
import "../../staking/interfaces/IFxMessageProcessor.sol";

interface IPZkp {
    function deposit(address user, bytes calldata depositData) external;
}

interface IRootChainManager {
    function depositFor(
        address receiver,
        address token,
        bytes calldata depositData
    ) external;
}

contract MockFxPortal is ImmutableOwnable, IRootChainManager, IFxStateSender {
    using TransferHelper for address;

    uint256[50] private __gap;

    // solhint-disable var-name-mixedcase
    address public immutable PZKP_TOKEN;
    address public immutable ZKP_TOKEN;

    // solhint-enable var-name-mixedcase

    event DepositForLog(address receiver, address token, bytes depositData);
    event SendMessageToChildLog(address _receiver, bytes _data);
    event ProcessMessageFromRootLog(
        uint256 stateId,
        address rootMessageSender,
        bytes data
    );

    constructor(
        address _owner,
        address _zkpToken,
        address _pZkpToken
    ) ImmutableOwnable(_owner) {
        require(
            _zkpToken != address(0) && _pZkpToken != address(0),
            "init: zero address"
        );

        ZKP_TOKEN = _zkpToken;
        PZKP_TOKEN = _pZkpToken;
    }

    // simulate message bridging
    function sendMessageToChild(address receiver, bytes calldata data)
        external
    {
        IFxMessageProcessor(receiver).processMessageFromRoot(
            uint256(0), // stateId
            msg.sender, // rootMessageSender
            data // content
        );

        emit SendMessageToChildLog(receiver, data);
    }

    // simulate token bridging
    function depositFor(
        address receiver,
        address token,
        bytes calldata depositData
    ) external {
        require(token == ZKP_TOKEN, "MOCKFX::depositFor: invalid token");

        uint256 amount = abi.decode(depositData, (uint256));
        require(amount > 0, "MOCKFX::depositFor: zero amount");

        token.safeTransferFrom(msg.sender, address(this), amount);
        IPZkp(PZKP_TOKEN).deposit(receiver, depositData);

        emit DepositForLog(receiver, token, depositData);
    }
}
