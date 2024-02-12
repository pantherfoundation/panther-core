// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.16;

import "../interfaces/IPureFiIssuerRequestResolver.sol";
import "../interfaces/IZAccountsRegistry.sol";

contract ZAccountsStatusResolver is IPureFiIssuerRequestResolver {
    IZAccountsRegistry public immutable ZACCOUNTS_REGISTRY;

    constructor(address _zAccountsRegistry) {
        require(_zAccountsRegistry != address(0), "init:zero address");
        ZACCOUNTS_REGISTRY = IZAccountsRegistry(_zAccountsRegistry);
    }

    function resolveRequest(
        uint8 /*_type*/,
        uint256 /*_ruleID*/,
        address _signer,
        address /*_from*/,
        address /*_to*/
    ) external view override returns (bool) {
        return ZACCOUNTS_REGISTRY.isZAccountWhitelisted(_signer);
    }
}
