// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../verifier/Verifier.sol";

// solhint-disable-next-line no-empty-blocks
contract MockVerifier is Verifier {
    function internalVerifyOrRevert(
        uint160 circuitId,
        uint256[] memory input,
        SnarkProof memory proof
    ) external view virtual {
        verifyOrRevert(circuitId, input, proof);
    }

    function internalGetVerifyingKey(
        uint160 circuitId
    ) external view returns (VerifyingKey memory) {
        return getVerifyingKey(circuitId);
    }
}
