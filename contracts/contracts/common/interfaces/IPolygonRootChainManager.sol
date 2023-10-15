// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IPolygonRootChainManager {
    function depositFor(
        address receiver,
        address token,
        bytes calldata depositData
    ) external;
}
