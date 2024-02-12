// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPolygonRootChainManager {
    function depositFor(
        address receiver,
        address token,
        bytes calldata depositData
    ) external;
}
