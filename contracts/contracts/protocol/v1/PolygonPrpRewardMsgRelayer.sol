// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "./interfaces/IPrpVoucherGrantor.sol";
import "./interfaces/IPrpConverter.sol";
import "../../staking/interfaces/IActionMsgReceiver.sol";
import "../../staking/interfaces/IFxMessageProcessor.sol";
import "./actions/PrpRewardBridgedDataCoder.sol";

/***
 * @title PolygonPrpRewardMsgRelayer
 * @notice It decodes PRP reward messages which come from Mainnet/Goerli
 * @dev It is assumed to run on the Polygon (or Mumbai) network.
 * It receives PRP reward messages from the `FxChild` contract (a contract of the "Fx-Portal" PoS bridge),
 * sanitizes and relays messages.
 */
contract PolygonPrpRewardMsgRelayer is
    PrpRewardBridgedDataCoder,
    IFxMessageProcessor
{
    event PrpRewardMsgRelayed(uint256 _nonce, bytes data);

    // solhint-disable var-name-mixedcase

    /// @notice Address of the `FxChild` contract on the Polygon/Mumbai network
    /// @dev `FxChild` is the contract of the "Fx-Portal" on the Polygon/Mumbai
    address public immutable FX_CHILD;

    /// @notice Address of the PolygonRewardSender on the mainnet/Goerli
    /// @dev It sends messages over the PoS bridge to this contract
    address public immutable TO_POLYGON_REWARD_SENDER;

    address public immutable PRP_VOUCHER_GRANTOR;

    address public immutable PRP_CONVERTER;

    // solhint-enable var-name-mixedcase

    /// @notice Message nonce (i.e. sequential number of the latest message)
    uint256 public nonce;

    /// @param _toPolygonRewardSender Address of the AdvancedStakeRewardAdviserAndMsgSender on the mainnet/Goerli
    /// @param _fxChild Address of the `FxChild` (Bridge) contract on Polygon/Mumbai
    constructor(
        // slither-disable-next-line similar-names
        address _toPolygonRewardSender,
        address _fxChild,
        address _prpVoucherGrantor,
        address _prpConverter
    ) {
        require(
            _fxChild != address(0) &&
                _toPolygonRewardSender != address(0) &&
                _prpVoucherGrantor != address(0) &&
                _prpConverter != address(0),
            "PMR:E01"
        );

        FX_CHILD = _fxChild;
        TO_POLYGON_REWARD_SENDER = _toPolygonRewardSender;
        PRP_VOUCHER_GRANTOR = _prpVoucherGrantor;
        PRP_CONVERTER = _prpConverter;
    }

    /// @param rootMessageSender Address on the mainnet/Goerli that sent the message
    /// @param content Message data
    function processMessageFromRoot(
        uint256, // stateId (Polygon PoS Bridge state sync ID, unused)
        address rootMessageSender,
        bytes calldata content
    ) external override {
        require(msg.sender == FX_CHILD, "PMR:INVALID_CALLER");
        require(
            rootMessageSender == TO_POLYGON_REWARD_SENDER,
            "PMR:INVALID_SENDER"
        );

        (
            uint256 _nonce,
            bytes4 prpGrantType,
            bytes32 secret
        ) = _decodeBridgedData(content);

        // Protection against replay attacks/errors. It's supposed that:
        // - failed `.onAction` shall not stop further messages bridging
        // - nonce is expected never be large enough to overflow.
        require(_nonce > nonce, "PMR:INVALID_NONCE");
        nonce = _nonce;

        // Trusted contract - no reentrancy guard needed
        IPrpVoucherGrantor(PRP_VOUCHER_GRANTOR).generateRewards(
            secret,
            0, // amount defined for prpGrantType will be used
            prpGrantType
        );

        // Trusted contract - no reentrancy guard needed
        IPrpConverter(PRP_CONVERTER).updateZkpReserve();

        emit PrpRewardMsgRelayed(_nonce, content);
    }
}
