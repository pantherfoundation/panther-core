// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

interface IRootChainManager {
    function depositFor(
        address receiver,
        address token,
        bytes calldata depositData
    ) external;
}
