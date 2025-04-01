// SPDX-License-Identifier: BUSDL-1.1
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("MockERC1155URI") {}

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) external {
        _mint(to, tokenId, amount, data);
    }
}
