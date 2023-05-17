// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IPrpGranter {
    function grant(bytes4 grantType, address grantee) external;
}
