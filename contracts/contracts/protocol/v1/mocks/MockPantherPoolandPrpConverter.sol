// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity ^0.8.19;

import "../PantherPoolV1.sol";
import "../interfaces/IVaultV1.sol";
import "../../../common/ImmutableOwnable.sol";
import "../../../common/UtilsLib.sol";
import { ERC20_TOKEN_TYPE } from "../../../common/Constants.sol";

contract MockPantherPoolandPrpConverter is ImmutableOwnable {
    // solhint-disable var-name-mixedcase
    address public ZKP_TOKEN;
    address public VAULT;
    address public PRP_CONVERTER;

    constructor(address _owner, address _zkpToken) ImmutableOwnable(_owner) {
        ZKP_TOKEN = _zkpToken;
    }

    function updatePrpConverterandVault(
        address _prpConverter,
        address _vault
    ) public {
        PRP_CONVERTER = _prpConverter;
        VAULT = _vault;
    }

    // solhint-disable no-unused-vars
    function createZzkpUtxoAndSpendPrpUtxo(
        uint256[] calldata inputs,
        SnarkProof calldata proof,
        uint32 transactionOptions,
        uint96 zkpAmountRounded,
        uint96 paymasterCompensation,
        bytes calldata privateMessages
    ) external returns (uint256 zAccountUtxoBusQueuePos) {
        require(msg.sender == PRP_CONVERTER, ERR_UNAUTHORIZED);

        // sample return value used
        zAccountUtxoBusQueuePos = 10;

        _lockZkp(msg.sender, zkpAmountRounded);
    }

    function _lockZkp(address from, uint256 amount) internal {
        // Trusted contract - no reentrancy guard needed
        IVaultV1(VAULT).lockAsset(
            LockData(
                ERC20_TOKEN_TYPE,
                ZKP_TOKEN,
                // tokenId undefined for ERC-20
                0,
                from,
                UtilsLib.safe96(amount)
            )
        );
    }
}
