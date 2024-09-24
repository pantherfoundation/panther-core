// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable max-line-length
pragma solidity ^0.8.19;

import "../../../../../../common/EIP712SignatureVerifier.sol";

abstract contract MiningRewardsSignatureVerifier is EIP712SignatureVerifier {
    bytes32 internal constant CLAIM_MINING_REWARD_TYPEHASH =
        keccak256(bytes("ClaimMiningReward(address receiver,uint256 version)"));

    uint8 public immutable CLAIM_MINING_REWARD_VERSION;

    constructor(uint8 claimMiningRewardVersion) {
        CLAIM_MINING_REWARD_VERSION = claimMiningRewardVersion;
    }

    function recoverOperator(
        address _receiver,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 claimMiningRewardDataHash = _getClaimMiningRewardDataHash(
            _receiver
        );

        bytes32 typedDataHash = toTypedDataHash(claimMiningRewardDataHash);

        return recover(typedDataHash, v, r, s);
    }

    function _getClaimMiningRewardDataHash(
        address _receiver
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    CLAIM_MINING_REWARD_TYPEHASH,
                    _receiver,
                    uint256(CLAIM_MINING_REWARD_VERSION)
                )
            );
    }
}
