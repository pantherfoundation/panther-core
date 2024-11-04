// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../../common/ImmutableOwnable.sol";
import "../core/interfaces/IPureFiIssuerRequestResolver.sol";

contract TestnetZAccountStatusResolver is ImmutableOwnable {
    address public immutable ZACCOUNTS_STATUS_RESOLVER;

    mapping(address => bool) public statusModifiers;
    mapping(address => bool) public whitelistedUsers;

    constructor(
        address _owner,
        address _zAccountsStatusResolver
    ) ImmutableOwnable(_owner) {
        ZACCOUNTS_STATUS_RESOLVER = _zAccountsStatusResolver;
    }

    function updateStatusModifiers(
        address _modifier,
        bool _status
    ) external onlyOwner {
        statusModifiers[_modifier] = _status;
    }

    function updateUserStatusBatch(
        address[] calldata _users,
        bool[] calldata _statuses
    ) external {
        require(statusModifiers[msg.sender], "unauthorized");
        require(_users.length == _statuses.length, "mismatch lengths");

        for (uint256 i = 0; i < _users.length; i++) {
            whitelistedUsers[_users[i]] = _statuses[i];
        }
    }

    function resolveRequest(
        uint8 _type,
        uint256 _ruleId,
        address _signer,
        address _from,
        address _to
    ) external view returns (bool) {
        return
            whitelistedUsers[_signer] &&
            IPureFiIssuerRequestResolver(ZACCOUNTS_STATUS_RESOLVER)
                .resolveRequest(_type, _ruleId, _signer, _from, _to);
    }
}
