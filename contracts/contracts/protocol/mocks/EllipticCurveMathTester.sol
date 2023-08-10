// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../crypto/EllipticCurveMath.sol";

// On built-in EC math contacts calls costs refer to https://eips.ethereum.org/EIPS/eip-1108
// (150 gas for ECADD, 6000 for ECMUL, 45000+34000*k for pairing check)
contract EllipticCurveMathTester is EllipticCurveMath {
    function testP1() external pure returns (G1Point memory) {
        return P1();
    }

    function testP2() external pure returns (G2Point memory) {
        return P2();
    }

    function testNegate(G1Point memory p)
        external
        pure
        returns (G1Point memory r)
    {
        return negate(p);
    }

    function testAddition(G1Point memory p1, G1Point memory p2)
        external
        view
        returns (G1Point memory r)
    {
        return addition(p1, p2);
    }

    function testScalar_mul(G1Point memory p, uint256 s)
        external
        view
        returns (G1Point memory r)
    {
        return scalar_mul(p, s);
    }

    function testPairing(G1Point[] memory p1, G2Point[] memory p2)
        external
        view
        returns (bool)
    {
        return pairing(p1, p2);
    }
}
