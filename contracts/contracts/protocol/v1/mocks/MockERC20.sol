// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MockERC20 is ERC20 {
    constructor(
        uint256 index,
        address owner
    ) ERC20(Strings.toString(index), Strings.toString(index)) {
        uint256 totalSupply = 1024 ether;
        _mint(owner, totalSupply);
    }
}
