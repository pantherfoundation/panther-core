// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import "../../../common/NonReentrant.sol";
import "../../../common/Claimable.sol";
import "../../../common/TransferHelper.sol";

/// @title ClaimTreasury
/// @notice Holds ZKP protocol fees and releases them once enough signers approve.
/// @dev Deploy behind a proxy and call {initialize}.
contract ClaimTreasury is NonReentrant, Claimable {
    using TransferHelper for address;

    struct ClaimRequest {
        address to;
        uint256 amount;
        uint256 approvals;
        bool claimAll;
        bool executed;
        uint256 nonce;
    }

    /// @notice Admin address allowed to manage rescue operations.
    address public treasuryOwner;

    /// @notice ZKP token managed by this treasury.
    address public zkpToken;

    /// @notice Number of approvals required for a claim to execute.
    uint256 public threshold;

    /// @notice Total registered signers.
    uint256 public signerCount;

    bool private initialized;
    uint256 private _nonce;

    mapping(address => bool) public isSigner;
    mapping(bytes32 => ClaimRequest) public claims;
    mapping(bytes32 => mapping(address => bool)) public approvals;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event ClaimProposed(
        bytes32 indexed claimId,
        address indexed proposer,
        address indexed to,
        uint256 amount,
        bool claimAll,
        uint256 nonce
    );
    event ClaimApproved(
        bytes32 indexed claimId,
        address indexed signer,
        uint256 approvals
    );
    event ClaimExecuted(
        bytes32 indexed claimId,
        address indexed executor,
        address indexed to,
        uint256 amount
    );

    modifier onlyOwner() {
        require(
            msg.sender == treasuryOwner,
            "ClaimTreasury: unauthorized owner"
        );
        _;
    }

    modifier onlySigner() {
        require(isSigner[msg.sender], "ClaimTreasury: unauthorized signer");
        _;
    }

    modifier whenInitialized() {
        require(initialized, "ClaimTreasury: not initialized");
        _;
    }

    /// @notice Initializes storage when the contract is deployed behind a proxy.
    function initialize(
        address owner_,
        address zkpToken_,
        address[] calldata initialSigners,
        uint256 threshold_
    ) external {
        require(!initialized, "ClaimTreasury: already initialized");
        require(owner_ != address(0), "ClaimTreasury: zero owner");
        require(zkpToken_ != address(0), "ClaimTreasury: zero token");
        require(threshold_ != 0, "ClaimTreasury: zero threshold");
        require(
            initialSigners.length >= threshold_,
            "ClaimTreasury: insufficient signers"
        );

        initialized = true;
        treasuryOwner = owner_;
        zkpToken = zkpToken_;
        threshold = threshold_;

        uint256 uniqueSigners;
        for (uint256 i; i < initialSigners.length; ++i) {
            address signer = initialSigners[i];
            require(signer != address(0), "ClaimTreasury: zero signer");
            require(!isSigner[signer], "ClaimTreasury: duplicate signer");
            isSigner[signer] = true;
            ++uniqueSigners;
        }
        signerCount = uniqueSigners;

        emit OwnershipTransferred(address(0), owner_);
    }

    /// @notice Transfers ownership to `newOwner`.
    function transferTreasuryOwnership(
        address newOwner
    ) external whenInitialized onlyOwner {
        require(newOwner != address(0), "ClaimTreasury: zero owner");
        address oldOwner = treasuryOwner;
        treasuryOwner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Opens a claim request and counts the proposer's approval.
    function submitClaim(
        address to,
        uint256 amount,
        bool claimAll
    ) external whenInitialized onlySigner returns (bytes32 claimId) {
        require(to != address(0), "ClaimTreasury: zero recipient");
        if (claimAll) {
            require(amount == 0, "ClaimTreasury: amount with claimAll");
        } else {
            require(amount != 0, "ClaimTreasury: zero amount");
        }

        claimId = _newClaimId(to, amount, claimAll);

        ClaimRequest storage request = claims[claimId];
        request.to = to;
        request.amount = amount;
        request.claimAll = claimAll;
        request.nonce = _nonce;

        emit ClaimProposed(
            claimId,
            msg.sender,
            to,
            amount,
            claimAll,
            request.nonce
        );

        _registerApproval(request, claimId, msg.sender);
    }

    /// @notice Approves an existing claim.
    function approveClaim(bytes32 claimId) external whenInitialized onlySigner {
        ClaimRequest storage request = claims[claimId];
        require(request.to != address(0), "ClaimTreasury: unknown claim");
        require(!request.executed, "ClaimTreasury: already executed");

        _registerApproval(request, claimId, msg.sender);
    }

    /// @notice Allows the owner to rescue tokens other than ZKP.
    function claimOtherErc20(
        address token,
        address to,
        uint256 amount
    ) external whenInitialized onlyOwner nonReentrant {
        require(token != zkpToken, "ClaimTreasury: reserved");
        require(to != address(0), "ClaimTreasury: zero recipient");
        _claimErc20(token, to, amount);
    }

    function _newClaimId(
        address to,
        uint256 amount,
        bool claimAll
    ) private returns (bytes32 claimId) {
        uint256 newNonce = ++_nonce;
        claimId = keccak256(
            abi.encodePacked(
                block.chainid,
                address(this),
                newNonce,
                to,
                amount,
                claimAll
            )
        );
        require(claims[claimId].to == address(0), "ClaimTreasury: reused id");
    }

    function _registerApproval(
        ClaimRequest storage request,
        bytes32 claimId,
        address signer
    ) private {
        require(!approvals[claimId][signer], "ClaimTreasury: already approved");
        approvals[claimId][signer] = true;
        request.approvals += 1;

        emit ClaimApproved(claimId, signer, request.approvals);

        if (request.approvals >= threshold) {
            _executeClaim(request, claimId);
        }
    }

    function _executeClaim(
        ClaimRequest storage request,
        bytes32 claimId
    ) private nonReentrant {
        require(!request.executed, "ClaimTreasury: already executed");
        request.executed = true;

        uint256 payout = request.claimAll
            ? TransferHelper.safeBalanceOf(zkpToken, address(this))
            : request.amount;
        require(payout != 0, "ClaimTreasury: empty claim");

        zkpToken.safeTransfer(request.to, payout);
        emit ClaimExecuted(claimId, msg.sender, request.to, payout);
    }
}
