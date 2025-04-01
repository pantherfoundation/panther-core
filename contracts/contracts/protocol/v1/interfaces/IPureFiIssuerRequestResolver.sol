// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

interface IPureFiIssuerRequestResolver {
    function resolveRequest(
        uint8 _type,
        uint256 _ruleID,
        address _signer,
        address _from,
        address _to
    ) external view returns (bool);
}
