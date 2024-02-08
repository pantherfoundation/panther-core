// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IPureFiIssuerRequestResolver {
    function resolveRequest(
        uint8 _type,
        uint256 _ruleID,
        address _signer,
        address _from,
        address _to
    ) external view returns (bool);
}
