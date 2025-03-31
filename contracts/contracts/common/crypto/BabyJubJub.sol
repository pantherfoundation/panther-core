// SPDX-License-Identifier: GPL
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// Implementer name - yondonfu
// Link to the implementation - https://github.com/yondonfu/sol-baby-jubjub/blob/master/contracts/CurveBabyJubJub.sol
pragma solidity ^0.8.16;
import "../Types.sol";
import { FIELD_SIZE } from "./SnarkConstants.sol";

string constant ERR_NOT_IN_FIELD = "BJJ:E01";
string constant ERR_NOT_IN_CURVE = "BJJ:E02";
string constant ERR_IDENTITY_UNEXPECTED = "BJJ:E03";

library BabyJubJub {
    // slither-disable too-many-digits

    // Curve parameters (twisted Edwards form)
    // E: A * x^2 + y^2 = 1 + D * x^2 * y^2
    uint256 private constant A = 168700;
    uint256 private constant D = 168696;
    // Field prime
    uint256 internal constant Q = FIELD_SIZE;

    // @dev Base point generates the subgroup of points P of Baby Jubjub satisfying l * P = O.
    // That is, it generates the set of points of order l and origin O.
    uint256 internal constant BASE8_X =
        5299619240641551281634865583518297030282874472190772894086521144482721001553;
    uint256 internal constant BASE8_Y =
        16950150798460657717958625567821834550301663161624707787222815936182638968203;

    // @dev Suborder (order of the subgroup)
    uint256 internal constant L =
        2736030358979909402780800718157159386076813972158567259200215660948447373041;

    // pm1d2 = (SNARK_FIELD - 1) >> 1 // same as `negative_one / 2`
    uint256 private constant PM1D2 =
        10944121435919637611123202872628637544274182200208017171849102093287904247808;

    // slither-enable too-many-digits

    /**
     * @dev Returns the given point in the "packed" form
     * For compatibility with circomlibjs (v.0.8) it packs (the sign of) X rather than Y
     * (either of the two coordinates may be "packed" for a twisted Edwards curve).
     */
    function pointPack(
        G1Point memory point
    ) internal pure returns (bytes32 _packed) {
        _packed = bytes32(point.y);

        if (point.x > PM1D2) {
            _packed = bytes32(
                point.y |
                    0x8000000000000000000000000000000000000000000000000000000000000000
            );
        }
    }

    /**
     * @dev Returns true if the given point is in the Baby Jubjub curve
     */
    function isInCurve(G1Point memory point) internal pure returns (bool) {
        require(point.x < Q && point.y < Q, ERR_NOT_IN_FIELD);

        // A * x^2 + y^2 = 1 + D * x^2 * y^2
        uint256 x2 = mulmod(point.x, point.x, Q);
        uint256 ax2 = mulmod(A, x2, Q);
        uint256 y2 = mulmod(point.y, point.y, Q);
        uint256 left = addmod(ax2, y2, Q);

        uint256 x2y2 = mulmod(x2, y2, Q);
        uint256 dx2y2 = mulmod(D, x2y2, Q);
        uint256 right = addmod(1, dx2y2, Q);

        return left == right;
    }

    /**
     * @dev Returns true if the point is the identity of the group of Baby Jubjub points
     */
    function isIdentity(G1Point memory point) internal pure returns (bool) {
        return (point.x == 0) && (point.y == 1);
    }

    /**
     * @dev Reverts if the point is either the identity or not in the Baby Jubjub subgroup
     */
    function requirePointInCurveExclIdentity(
        G1Point memory point
    ) internal pure {
        require(!isIdentity(point), ERR_IDENTITY_UNEXPECTED);
        require(isInCurve(point), ERR_NOT_IN_CURVE);
    }

    /**
     * @dev Returns true if the given point is in the Baby Jubjub subgroup
     * (beware of high gas costs)
     */
    function isInSubgroup(G1Point memory point) internal view returns (bool) {
        if (isInCurve(point)) {
            G1Point memory res = mulPointEscalar(point, L);
            return isIdentity(res);
        }

        return false;
    }

    function mulPointEscalar(
        G1Point memory point,
        uint256 scalar
    ) internal view returns (G1Point memory r) {
        r.x = 0;
        r.y = 1;

        uint256 rem = scalar;
        G1Point memory exp = point;

        while (rem != uint256(0)) {
            if ((rem & 1) == 1) {
                r = pointAdd(r, exp);
            }
            exp = pointAdd(exp, exp);
            rem = rem >> 1;
        }
        r.x = r.x % Q;
        r.y = r.y % Q;

        return r;
    }

    /**
     * @dev Add 2 points on the Baby Jubjub curve
     * Formulae for adding 2 points on a twisted Edwards curve:
     * x3 = (x1y2 + y1x2) / (1 + dx1x2y1y2)
     * y3 = (y1y2 - ax1x2) / (1 - dx1x2y1y2)
     */
    function pointAdd(
        G1Point memory g1,
        G1Point memory g2
    ) internal view returns (G1Point memory) {
        uint256 x3 = 0;
        uint256 y3 = 0;
        if (g1.x == 0 && g1.y == 0) {
            return G1Point(x3, y3);
        }

        if (g2.x == 0 && g1.y == 0) {
            return G1Point(x3, y3);
        }

        uint256 x1x2 = mulmod(g1.x, g2.x, Q);
        uint256 y1y2 = mulmod(g1.y, g2.y, Q);
        uint256 dx1x2y1y2 = mulmod(D, mulmod(x1x2, y1y2, Q), Q);
        uint256 x3Num = addmod(mulmod(g1.x, g2.y, Q), mulmod(g1.y, g2.x, Q), Q);
        uint256 y3Num = submod(y1y2, mulmod(A, x1x2, Q), Q);

        x3 = mulmod(x3Num, inverse(addmod(1, dx1x2y1y2, Q)), Q);
        y3 = mulmod(y3Num, inverse(submod(1, dx1x2y1y2, Q)), Q);
        return G1Point(x3, y3);
    }

    /**
     * @dev Perform modular subtraction
     */
    function submod(
        uint256 _a,
        uint256 _b,
        uint256 _mod
    ) private pure returns (uint256) {
        uint256 aNN = _a;

        if (_a <= _b) {
            aNN += _mod;
        }

        return addmod(aNN - _b, 0, _mod);
    }

    /**
     * @dev Compute modular inverse of a number
     */
    function inverse(uint256 _a) private view returns (uint256) {
        // We can use Euler's theorem instead of the extended Euclidean algorithm
        // Since m = Q and Q is prime we have: a^-1 = a^(m - 2) (mod m)
        return expmod(_a, Q - 2, Q);
    }

    /**
     * @dev Helper function to call the bigModExp precompile
     */
    function expmod(
        uint256 _b,
        uint256 _e,
        uint256 _m
    ) private view returns (uint256 o) {
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            let memPtr := mload(0x40)
            mstore(memPtr, 0x20) // Length of base _b
            mstore(add(memPtr, 0x20), 0x20) // Length of exponent _e
            mstore(add(memPtr, 0x40), 0x20) // Length of modulus _m
            mstore(add(memPtr, 0x60), _b) // Base _b
            mstore(add(memPtr, 0x80), _e) // Exponent _e
            mstore(add(memPtr, 0xa0), _m) // Modulus _m

            // The bigModExp precompile is at 0x05
            let success := staticcall(gas(), 0x05, memPtr, 0xc0, memPtr, 0x20)
            switch success
            case 0 {
                revert(0x0, 0x0)
            }
            default {
                o := mload(memPtr)
            }
        }
        // solhint-enable no-inline-assembly
    }
}
