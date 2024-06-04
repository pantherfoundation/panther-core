// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../../common/ImmutableOwnable.sol";

contract MockLinkToken is ERC20, ImmutableOwnable {
    constructor(
        address _owner
    ) ERC20("MockLinkToken", "LINK") ImmutableOwnable(_owner) {
        uint256 totalSupply = 1000000000 ether;
        _mint(_owner, totalSupply);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
