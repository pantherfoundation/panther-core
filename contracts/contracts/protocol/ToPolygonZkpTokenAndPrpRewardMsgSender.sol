// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "../staking/interfaces/IFxStateSender.sol";
import "../common/interfaces/IPolygonRootChainManager.sol";

import "../common/ImmutableOwnable.sol";
import "../common/TransferHelper.sol";

import "./interfaces/IProtocolRewardController.sol";
import "./actions/PrpRewardBridgedDataCoder.sol";
import { GT_ZKP_RELEASE } from "../common/Constants.sol";

/**
 * @title ToPolygonZkpTokenAndPrpRewardMsgSender
 * @author Pantherprotocol Contributors
 * @notice Responsible for Bridging $ZKPs and arbitrary messages to the Polygon chain.
 * @dev This contract lives on Ethereum chain and asks from PantherRewardController to
 * release $ZKP rewards and then if there are releasable $ZKPs, it interacts with the ETH<->Polygon bridge to
 * send them to the Polygon chain via Polygon FXRoot contract. Anyone can try to release and bridge ZKPs.
 * This contract also bridge the data which contains the address of user who has bridged ZKPs along with
 * the specific grant type (ZKP_RELEASE_AND_BRIDGE_PRP_GRANT_TYPE) which then is used to grant
 * PRP rewards to the user.
 */

contract ToPolygonZkpTokenAndPrpRewardMsgSender is
    ImmutableOwnable,
    PrpRewardBridgedDataCoder
{
    // solhint-disable var-name-mixedcase

    /// @notice address of PrpConverter on Polygon
    address public immutable PRP_CONVERTER;

    /// @notice address of protocolRewardMessageRelayer on Polygon
    address public immutable PROTOCOL_REWARD_MESSAGE_RELAYER;

    /// @notice address of RewardController on Polygon
    address public immutable PANTHER_REWARD_CONTROLLER;

    /// @notice Address of the $ZKP token contract
    address private immutable ZKP_TOKEN;

    /// @notice address RootChainManagerProxy on Ethereum
    address private immutable ROOR_CHAIN_MANAGER_PROXY;

    /// @notice erc20PRedicateProxy must be approved for transferring ERC20s
    address private immutable ERC20_PREDICATE_PROXY;

    /// @notice Address of the `FxRoot` contract on the mainnet/Goerli network
    /// @dev `FxRoot` is the contract of the "Fx-Portal" on the mainnet/Goerli.
    address private immutable FX_ROOT;

    // solhint-enable var-name-mixedcase

    /// @notice Message nonce (i.e. sequential number of the latest message)
    uint128 public nonce;

    /// @notice Last bridge execution timestamp
    uint128 public lastBridgeExecution;

    event ZkpTokenSent(uint256 zkpAmount);
    event PrpRewardMessageSent(bytes message);

    constructor(
        address _owner,
        address _prpConverter,
        address _protocolRewardMessageRelayer,
        address _pantherRewardController,
        address _zkpToken,
        address _rootChainManagerProxy,
        address _erc20PredicateProxy,
        address _fxRoot
    ) ImmutableOwnable(_owner) {
        require(
            _prpConverter != address(0) &&
                _protocolRewardMessageRelayer != address(0) &&
                _pantherRewardController != address(0) &&
                _zkpToken != address(0) &&
                _rootChainManagerProxy != address(0) &&
                _erc20PredicateProxy != address(0) &&
                _fxRoot != address(0),
            "PRS:E1"
        );

        PRP_CONVERTER = _prpConverter;
        PROTOCOL_REWARD_MESSAGE_RELAYER = _protocolRewardMessageRelayer;
        PANTHER_REWARD_CONTROLLER = _pantherRewardController;
        ZKP_TOKEN = _zkpToken;
        ROOR_CHAIN_MANAGER_PROXY = _rootChainManagerProxy;
        ERC20_PREDICATE_PROXY = _erc20PredicateProxy;
        FX_ROOT = _fxRoot;
    }

    function bridgeZkpTokensAndPrpRewardsMessage(bytes32 secret) external {
        // known contract - no reentrancy guard needed
        uint256 releasable = IProtocolRewardController(
            PANTHER_REWARD_CONTROLLER
        ).vestRewards();

        if (releasable > 0) {
            _bridgeZkpTokens(releasable);

            _bridgePrpRewardMessage(secret);

            lastBridgeExecution = uint128(block.timestamp);
        }
    }

    function _bridgeZkpTokens(uint256 _amount) private {
        TransferHelper.safeApprove(ZKP_TOKEN, ERC20_PREDICATE_PROXY, _amount);

        IPolygonRootChainManager(ROOR_CHAIN_MANAGER_PROXY).depositFor(
            PRP_CONVERTER,
            ZKP_TOKEN,
            abi.encode(_amount)
        );

        emit ZkpTokenSent(_amount);
    }

    function _bridgePrpRewardMessage(bytes32 secret) private {
        // Overflow ignored as the nonce is unexpected ever be that big
        uint32 _nonce = uint32(nonce + 1);
        nonce = uint128(_nonce);

        // TODO: the contract is better to include the `PRP_CONVERTER` address so that
        // `PROTOCOL_REWARD_MESSAGE_RELAYER` get the address and execute updateZkpReserve()
        bytes memory content = _encodeBridgedData(
            _nonce,
            GT_ZKP_RELEASE,
            secret
        );

        IFxStateSender(FX_ROOT).sendMessageToChild(
            PROTOCOL_REWARD_MESSAGE_RELAYER,
            content
        );

        emit PrpRewardMessageSent(content);
    }
}
