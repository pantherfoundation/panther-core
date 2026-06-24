// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "../../common/ImmutableOwnable.sol";
import "../../common/NonReentrant.sol";
import "../../common/OnERC721Received.sol";
import "../../common/OnERC1155Received.sol";
import { LockData } from "../../common/Types.sol";
import "./interfaces/IVaultV0.sol";

interface IErc20Min {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IErc721Min {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
}

/**
 * @title VaultV0Frozen
 * @notice Frozen replacement implementation for the v0 Vault behind
 * the existing Vault proxy on Polygon.
 *
 * Effects of upgrading the Vault proxy to this implementation:
 *   - `lockAsset` and `unlockAsset` always revert, regardless of caller.
 *     `PantherPoolV0.exit()` and `PantherPoolV0.generateDeposits()` therefore
 *     revert too — the v0 MASP path is permanently disabled.
 *   - Rewards previously locked here (ZKP and PNFT) become claimable through
 *     a Merkle-tree-based `claim` function, with eligibility computed off-chain
 *     from the on-chain stake / reward / exit history and committed via a
 *     single Merkle `root` set once by the new owner.
 *
 * Storage layout: the prior implementation had no storage of its own (only
 * immutables in `ImmutableOwnable`). Variables added here therefore start at
 * slot 0 with no collision risk. Do not reorder, remove, or insert into the
 * storage variable list below without a coordinated migration.
 */
contract VaultV0Frozen is
    ImmutableOwnable,
    NonReentrant,
    OnERC721Received,
    OnERC1155Received,
    IVaultV0
{
    // --- Immutables (live in implementation bytecode, not storage) ---

    /// @notice The ERC-20 token (PZKP) that funded the advanced-stake rewards.
    address public immutable ZKP_TOKEN;
    /// @notice The ERC-721 token (PNFT) that funded the advanced-stake rewards.
    address public immutable NFT_TOKEN;

    // --- Constants ---

    /// @notice First PNFT tokenId held by this Vault (inclusive).
    /// Verified on-chain: PNftToken's internal counter starts at 1, and
    /// `ownerOf(0)` reverts ("invalid token ID") at the time of deployment.
    uint16 public constant FIRST_NFT_ID = 1;
    /// @notice Last PNFT tokenId held by this Vault (inclusive).
    /// Verified on-chain: `NFT.balanceOf(vault) == 2000`, `ownerOf(2000) == vault`,
    /// and `ownerOf(2001)` reverts at the time of deployment.
    uint16 public constant LAST_NFT_ID = 2000;
    /// @notice Time after `setRoot` during which only users can withdraw via
    /// `claim`. The owner sweep functions revert until this window has passed.
    uint256 public constant CLAIM_WINDOW = 365 days;

    // --- Storage (slot 0 is _reentrancyStatus from NonReentrant) ---

    /// @notice Merkle root committing the (user, zkpAmount, nftCount) tuples.
    /// Settable exactly once by `OWNER`, in a follow-up proposal after this
    /// implementation is in place and the entitlement set is finalised.
    bytes32 public root;

    /// @notice Per-address claim flag. A user can claim at most once.
    mapping(address => bool) public claimed;

    /// @notice Total PNFTs dispensed so far. The next claim starts at
    /// `FIRST_NFT_ID + nftsClaimed`.
    uint16 public nftsClaimed;

    /// @notice Block timestamp at which `setRoot` was called. The owner sweep
    /// functions unlock at `claimOpenedAt + CLAIM_WINDOW`. Zero until
    /// `setRoot` is called.
    uint256 public claimOpenedAt;

    // --- Events ---

    event RootSet(bytes32 root);
    event Claimed(
        address indexed user,
        uint256 zkpAmount,
        uint16 nftCount,
        uint16 firstNftId
    );
    event OwnerSwept(
        address indexed token,
        address indexed to,
        uint256 amountOrCount
    );

    constructor(
        address _owner,
        address _zkpToken,
        address _nftToken
    ) ImmutableOwnable(_owner) {
        require(
            _zkpToken != address(0) && _nftToken != address(0),
            "VFrozen: zero token"
        );
        ZKP_TOKEN = _zkpToken;
        NFT_TOKEN = _nftToken;
    }

    // --- IVaultV0 surface: frozen ---

    function lockAsset(LockData calldata) external pure override {
        revert("VFrozen: frozen");
    }

    function unlockAsset(LockData calldata) external pure override {
        revert("VFrozen: frozen");
    }

    // --- Claim path ---

    /// @notice Commit the entitlement Merkle root. May only be called once.
    /// Records the timestamp so the owner sweep functions unlock exactly
    /// `CLAIM_WINDOW` later.
    function setRoot(bytes32 _root) external onlyOwner {
        require(root == bytes32(0), "VFrozen: root set");
        require(_root != bytes32(0), "VFrozen: zero root");
        root = _root;
        claimOpenedAt = block.timestamp;
        emit RootSet(_root);
    }

    /// @notice Claim the caller's entitlement.
    /// @param zkpAmount Amount of ZKP to receive (in wei).
    /// @param nftCount  Number of PNFTs the caller is entitled to (committed
    ///                  in the Merkle leaf). Must match the leaf even if
    ///                  `claimNft == false`.
    /// @param claimNft  If `false`, NFTs are NOT dispensed and the NFT cursor
    ///                  is NOT advanced. The caller still loses the chance to
    ///                  claim later (`claimed` flag is set). Useful for users
    ///                  who only want their ZKP and want to skip the gas of
    ///                  receiving NFTs.
    /// @param proof     Merkle proof for leaf
    ///                  `keccak256(bytes.concat(keccak256(abi.encode(
    ///                      msg.sender, zkpAmount, nftCount
    ///                  ))))`.
    function claim(
        uint256 zkpAmount,
        uint16 nftCount,
        bool claimNft,
        bytes32[] calldata proof
    ) external nonReentrant {
        require(root != bytes32(0), "VFrozen: not open");
        require(!claimed[msg.sender], "VFrozen: claimed");
        uint16 nftsToTransfer = claimNft ? nftCount : 0;
        require(
            zkpAmount != 0 || nftsToTransfer != 0,
            "VFrozen: empty claim"
        );

        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(msg.sender, zkpAmount, nftCount))
            )
        );
        require(
            MerkleProof.verify(proof, root, leaf),
            "VFrozen: bad proof"
        );

        claimed[msg.sender] = true;

        uint16 first = FIRST_NFT_ID + nftsClaimed;
        if (nftsToTransfer > 0) {
            uint16 newCount = nftsClaimed + nftsToTransfer;
            require(
                FIRST_NFT_ID + newCount - 1 <= LAST_NFT_ID,
                "VFrozen: nft exhausted"
            );
            nftsClaimed = newCount;
            // `transferFrom` (not `safeTransferFrom`) avoids reverting for
            // recipients that don't implement IERC721Receiver — notably EOAs
            // with an EIP-7702 delegation set to a non-receiver smart wallet.
            for (uint16 i = 0; i < nftsToTransfer; ++i) {
                IErc721Min(NFT_TOKEN).transferFrom(
                    address(this),
                    msg.sender,
                    uint256(first + i)
                );
            }
        }

        if (zkpAmount > 0) {
            require(
                IErc20Min(ZKP_TOKEN).transfer(msg.sender, zkpAmount),
                "VFrozen: zkp xfer failed"
            );
        }

        emit Claimed(msg.sender, zkpAmount, nftsToTransfer, first);
    }

    // --- View helpers (read-only, for the claim UI) ---

    /// @notice Whether claims are open (i.e. the Merkle root has been set).
    function isClaimOpen() external view returns (bool) {
        return root != bytes32(0);
    }

    /// @notice Number of PNFTs still held by this Vault and not yet dispensed.
    function nftsRemaining() external view returns (uint16) {
        return (LAST_NFT_ID - FIRST_NFT_ID + 1) - nftsClaimed;
    }

    /// @notice The PNFT tokenId that the next claim would start at. The next
    /// claim of `n` NFTs receives ids `[nextNftId, nextNftId + n - 1]`.
    function nextNftId() external view returns (uint16) {
        return FIRST_NFT_ID + nftsClaimed;
    }

    /// @notice Verify the Merkle proof for the (`user`, `zkpAmount`, `nftCount`)
    /// tuple against the current root. Does NOT check the `claimed` flag.
    function verifyClaim(
        address user,
        uint256 zkpAmount,
        uint16 nftCount,
        bytes32[] calldata proof
    ) public view returns (bool) {
        if (root == bytes32(0)) return false;
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(user, zkpAmount, nftCount))
            )
        );
        return MerkleProof.verify(proof, root, leaf);
    }

    /// @notice Combined predicate the UI can hit in a single eth_call: would
    /// `claim(zkpAmount, nftCount, claimNft, proof)` from `user` currently
    /// succeed?
    function isClaimable(
        address user,
        uint256 zkpAmount,
        uint16 nftCount,
        bool claimNft,
        bytes32[] calldata proof
    ) external view returns (bool) {
        if (claimed[user]) return false;
        uint16 nftsToTransfer = claimNft ? nftCount : 0;
        if (zkpAmount == 0 && nftsToTransfer == 0) return false;
        if (nftsToTransfer > 0) {
            uint16 remaining =
                (LAST_NFT_ID - FIRST_NFT_ID + 1) - nftsClaimed;
            if (nftsToTransfer > remaining) return false;
        }
        return verifyClaim(user, zkpAmount, nftCount, proof);
    }

    /// @notice Unix timestamp at which the owner sweep functions unlock.
    /// Returns 0 if `setRoot` has not yet been called.
    function sweepUnlocksAt() external view returns (uint256) {
        if (claimOpenedAt == 0) return 0;
        return claimOpenedAt + CLAIM_WINDOW;
    }

    // --- Owner sweep (residuals after claim period) ---

    /// @dev Allow sweeping only once `CLAIM_WINDOW` has elapsed since the
    /// claims were opened (via `setRoot`). If `setRoot` has not been called,
    /// sweep is permanently blocked — funds remain with the contract until
    /// claims open.
    modifier afterClaimWindow() {
        require(claimOpenedAt != 0, "VFrozen: claims not open");
        // slither-disable-next-line timestamp
        require(
            block.timestamp >= claimOpenedAt + CLAIM_WINDOW,
            "VFrozen: too early"
        );
        _;
    }

    /// @notice Sweep an ERC-20 balance to `to`. Intended for residual ZKP that
    /// stays unclaimed after the 1-year claim window ends.
    function ownerSweepErc20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner afterClaimWindow nonReentrant {
        require(to != address(0), "VFrozen: zero to");
        require(
            IErc20Min(token).transfer(to, amount),
            "VFrozen: sweep failed"
        );
        emit OwnerSwept(token, to, amount);
    }

    /// @notice Sweep a list of PNFT tokenIds to `to`. Used to recover NFTs
    /// that no one claimed after the 1-year claim window ends.
    function ownerSweepNft(
        address to,
        uint256[] calldata tokenIds
    ) external onlyOwner afterClaimWindow nonReentrant {
        require(to != address(0), "VFrozen: zero to");
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            IErc721Min(NFT_TOKEN).transferFrom(
                address(this),
                to,
                tokenIds[i]
            );
        }
        emit OwnerSwept(NFT_TOKEN, to, tokenIds.length);
    }
}
