// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "../../common/ImmutableOwnable.sol";
import "../../common/Claimable.sol";

/**
 * @title VaultV0WithClaim
 * @notice Vault with claim functionality. It allows users to claim their rewards instead
 * of directly calling PantherPool. This contract is developed as part of deprecation of
 * the advanced stake program.
 */
contract VaultV0WithClaim is ImmutableOwnable, Claimable {
    using TransferHelper for address;

    uint256 public constant TOTAL_NFT_AMOUNT = 2000;
    uint256 public constant WITHDRAWAL_DELAY = 365 days;

    uint256 public immutable DEPLOYED_TIMESTAMP;
    address public immutable ZKP;
    address public immutable NFT;

    mapping(address => bool) public claimedUsers;

    bytes32 public root;
    uint8 public levels;
    uint16 public leavesNum;
    uint16 public nextNftId;

    event Initialized(bytes32 _root, uint16 _leavesNum, uint8 _levels);
    event Claimed(address indexed account, uint16 nftAmount, uint256 zkpAmount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);

    constructor(
        address _owner,
        address _zkp,
        address _nft
    ) ImmutableOwnable(_owner) {
        ZKP = _zkp;
        NFT = _nft;
        DEPLOYED_TIMESTAMP = block.timestamp;
    }

    function initialize(
        bytes32 _root,
        uint16 _leavesNum,
        uint8 _levels
    ) external onlyOwner {
        require(root == bytes32(0), "already initialized");

        require(_root != bytes32(0), "invalid root");
        require(_leavesNum > 0, "invalid leaves num");
        require(_levels > 0, "invalid levels");

        root = _root;
        leavesNum = _leavesNum;
        levels = _levels;

        emit Initialized(_root, _leavesNum, _levels);
    }

    function claim(
        uint16 nftAmount,
        uint256 zkpAmount,
        uint256 leafIndex,
        bytes32[] memory proofSiblings,
        bool claimNft
    ) external {
        require(root != bytes32(0), "not initialized");
        require(nftAmount > 0 || zkpAmount > 0, "invalid amount");

        require(!claimedUsers[msg.sender], "already claimed");

        uint256 zkpBalance = ZKP.safeBalanceOf(address(this));
        require(zkpBalance >= zkpAmount, "insufficient zkp balance");

        require(
            verify(nftAmount, zkpAmount, leafIndex, proofSiblings),
            "invalid proof"
        );

        claimedUsers[msg.sender] = true;

        if (zkpAmount > 0) {
            ZKP.safeTransfer(msg.sender, zkpAmount);
        }

        if (nftAmount > 0 && claimNft) {
            uint16 _nextNftId = nextNftId;

            for (uint256 i = 0; i < nftAmount; ) {
                unchecked {
                    _nextNftId++;
                    i++;
                }
                NFT.safeTransferFrom(address(this), msg.sender, _nextNftId);
            }

            require(_nextNftId <= TOTAL_NFT_AMOUNT, "exceeds total nft amount");
            nextNftId = _nextNftId;
        }

        emit Claimed(msg.sender, nftAmount, zkpAmount);
    }

    function verify(
        uint16 nftAmount,
        uint256 zkpAmount,
        uint256 leafIndex,
        bytes32[] memory proofSiblings
    ) public view returns (bool) {
        require(leafIndex < leavesNum, "invalid leaf index");
        require(proofSiblings.length == levels, "invalid siblings length");

        bytes32 leaf = keccak256(
            abi.encodePacked(msg.sender, nftAmount, zkpAmount)
        );

        bytes32 _hash = leaf;
        uint256 proofPathIndice;

        // using `proofSiblings[]` length as the tree depth
        for (uint256 i = 0; i < proofSiblings.length; i++) {
            // getting the bit at position `i` and check if it's 0 or 1
            proofPathIndice = (leafIndex >> i) & 1;
            if (proofPathIndice == 0) {
                _hash = keccak256(abi.encodePacked(_hash, proofSiblings[i]));
            } else {
                _hash = keccak256(abi.encodePacked(proofSiblings[i], _hash));
            }
        }
        return _hash == root;
    }

    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(
            block.timestamp >= DEPLOYED_TIMESTAMP + WITHDRAWAL_DELAY,
            "withdrawal delay not passed"
        );

        _claimEthOrErc20(token, to, amount);

        emit Withdrawn(token, to, amount);
    }
}
