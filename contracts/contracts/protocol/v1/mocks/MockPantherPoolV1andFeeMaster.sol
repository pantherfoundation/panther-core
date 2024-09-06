// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity ^0.8.19;

import "../PantherPoolV1.sol";
import "./MockPantherPoolV1.sol";
import "../mocks/FakeVault.sol";
import "../interfaces/IVaultV1.sol";
import "../../../common/ImmutableOwnable.sol";
import "../../../common/UtilsLib.sol";
import { NATIVE_TOKEN, NATIVE_TOKEN_TYPE, ERC20_TOKEN_TYPE } from "../../../common/Constants.sol";

contract MockPantherPoolV1andFeeMaster is ImmutableOwnable {
    // solhint-disable var-name-mixedcase
    address public FEE_MASTER;
    address public VAULT;

    mapping(address => uint256) public feeMasterDebt;
    mapping(address => bool) public vaultAssetUnlockers;

    constructor(address _owner) ImmutableOwnable(_owner) {}

    function updateVaultAssetUnlocker(
        address _unlocker,
        bool _status
    ) external onlyOwner {
        vaultAssetUnlockers[_unlocker] = _status;
    }

    function unlockAssetFromVault(LockData calldata data) external {
        require(vaultAssetUnlockers[msg.sender], "mockPoolV1: unauthorized");

        IVaultV1(VAULT).unlockAsset(data);
    }

    function updateFeeMasterandVault(
        address _feeMaster,
        address _vault
    ) public onlyOwner {
        FEE_MASTER = _feeMaster;
        VAULT = _vault;
    }

    function adjustVaultAssetsAndUpdateTotalFeeMasterDebt(
        address token,
        int256 netAmount,
        address extAccount
    ) external payable {
        require(msg.sender == FEE_MASTER, "unauthorized");

        uint8 tokenType = token == NATIVE_TOKEN
            ? NATIVE_TOKEN_TYPE
            : ERC20_TOKEN_TYPE;

        LockData memory data = LockData({
            tokenType: tokenType,
            token: token,
            tokenId: 0,
            extAccount: extAccount,
            extAmount: netAmount > 0
                ? uint96(uint256(netAmount))
                : uint96(uint256(-netAmount))
        });

        if (netAmount > 0) {
            _lockAssetAndIncreaseFeeMasterDebt(data);
        }

        if (netAmount < 0) {
            _unlockAssetAndDecreaseFeeMasterDebt(data);
        }
    }

    function _lockAssetAndIncreaseFeeMasterDebt(LockData memory data) private {
        address token = data.token;

        feeMasterDebt[token] += data.extAmount;
        uint256 msgValue = token == NATIVE_TOKEN ? msg.value : 0;

        IVaultV1(VAULT).lockAsset{ value: msgValue }(data);
    }

    function _unlockAssetAndDecreaseFeeMasterDebt(
        LockData memory data
    ) private {
        feeMasterDebt[data.token] -= data.extAmount;

        IVaultV1(VAULT).unlockAsset(data);
    }

    function setDebt(address token, uint256 amt) public {
        feeMasterDebt[token] += amt;
    }
}
