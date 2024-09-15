// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
// solhint-disable max-line-length
pragma solidity ^0.8.19;

import "../../../../../../common/EIP712SignatureVerifier.sol";
import { G1Point } from "../../../../../../common/Types.sol";

abstract contract ProvidersKeysSignatureVerifier is EIP712SignatureVerifier {
    bytes32 internal constant G1_POINT_TYPEHASH =
        keccak256(bytes("G1Point(uint256 x,uint256 y)"));

    bytes32 internal constant REGISTER_KEY_TYPEHASH =
        keccak256(
            bytes(
                "RegisterKey(uint16 keyringId,G1Point pubRootSpendingKey,uint32 expiryDate,bytes32[] proofSiblings,uint256 version)G1Point(uint256 x,uint256 y)"
            )
        );
    bytes32 internal constant REVOKE_KEY_TYPEHASH =
        keccak256(
            bytes(
                "RevokeKey(uint16 keyringId,uint16 keyIndex,G1Point pubRootSpendingKey,uint32 expiryDate,bytes32[] proofSiblings,uint256 version)G1Point(uint256 x,uint256 y)"
            )
        );
    bytes32 internal constant EXTEND_KEY_EXPIRY_TYPEHASH =
        keccak256(
            bytes(
                "ExtendKeyExpiry(uint16 keyIndex,G1Point pubRootSpendingKey,uint32 expiryDate,uint32 newExpiryDate,bytes32[] proofSiblings,uint256 version)G1Point(uint256 x,uint256 y)"
            )
        );
    bytes32 internal constant UPDATE_KEY_OPERATOR_TYPEHASH =
        keccak256(
            bytes(
                "UpdateKeyOperator(uint32 keyringId,address newOperator,uint256 version)"
            )
        );

    uint8 public immutable KEYRING_VERSION;

    constructor(uint8 keyringVersion) {
        KEYRING_VERSION = keyringVersion;
    }

    /// to be used in `registerKeyWithSignature()`
    function recoverOperator(
        uint16 _keyringId,
        G1Point memory _pubRootSpendingKey,
        uint32 _expiryDate,
        bytes32[] memory proofSiblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 registerKeyDataHash = _getRegisterKeyDataHash(
            _keyringId,
            _pubRootSpendingKey,
            _expiryDate,
            proofSiblings
        );

        bytes32 typedDataHash = toTypedDataHash(registerKeyDataHash);

        return recover(typedDataHash, v, r, s);
    }

    /// to be used in `revokeKeyWithSignature()`
    function recoverOperator(
        uint16 _keyringId,
        uint16 _keyIndex,
        G1Point memory _pubRootSpendingKey,
        uint32 _expiryDate,
        bytes32[] memory proofSiblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 revokeKeyDataHash = _getRevokeKeyDataHash(
            _keyringId,
            _keyIndex,
            _pubRootSpendingKey,
            _expiryDate,
            proofSiblings
        );

        bytes32 typedDataHash = toTypedDataHash(revokeKeyDataHash);

        return recover(typedDataHash, v, r, s);
    }

    /// to be used in `extendKeyExpiryWithSignature`
    function recoverOperator(
        uint16 _keyIndex,
        G1Point memory _pubRootSpendingKey,
        uint32 _expiryDate,
        uint32 _newExpiryDate,
        bytes32[] memory proofSiblings,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 extendKeyExpiryDataHash = _getExtendKeyExpiryDataHash(
            _keyIndex,
            _pubRootSpendingKey,
            _expiryDate,
            _newExpiryDate,
            proofSiblings
        );

        bytes32 typedDataHash = toTypedDataHash(extendKeyExpiryDataHash);

        return recover(typedDataHash, v, r, s);
    }

    /// to be used in `updateKeyringOperatorWithSignature`
    function recoverOperator(
        uint16 _keyringId,
        address _newOperator,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 updateKeyOperatorDataHash = _getUpdateKeyOperatorDataHash(
            _keyringId,
            _newOperator
        );

        bytes32 typedDataHash = toTypedDataHash(updateKeyOperatorDataHash);

        return recover(typedDataHash, v, r, s);
    }

    function _getG1PointDataHash(
        G1Point memory _g1Point
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(G1_POINT_TYPEHASH, _g1Point.x, _g1Point.y));
    }

    function _getRegisterKeyDataHash(
        uint16 _keyringId,
        G1Point memory _pubRootSpendingKey,
        uint32 _expiryDate,
        bytes32[] memory proofSiblings
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    REGISTER_KEY_TYPEHASH,
                    _keyringId,
                    _getG1PointDataHash(_pubRootSpendingKey),
                    _expiryDate,
                    _getProofSiblingsHash(proofSiblings),
                    uint256(KEYRING_VERSION)
                )
            );
    }

    function _getRevokeKeyDataHash(
        uint16 _keyringId,
        uint16 _keyIndex,
        G1Point memory _pubRootSpendingKey,
        uint32 _expiryDate,
        bytes32[] memory proofSiblings
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    REVOKE_KEY_TYPEHASH,
                    _keyringId,
                    _keyIndex,
                    _getG1PointDataHash(_pubRootSpendingKey),
                    _expiryDate,
                    _getProofSiblingsHash(proofSiblings),
                    uint256(KEYRING_VERSION)
                )
            );
    }

    function _getExtendKeyExpiryDataHash(
        uint16 _keyIndex,
        G1Point memory _pubRootSpendingKey,
        uint32 _expiryDate,
        uint32 _newExpiryDate,
        bytes32[] memory proofSiblings
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EXTEND_KEY_EXPIRY_TYPEHASH,
                    _keyIndex,
                    _getG1PointDataHash(_pubRootSpendingKey),
                    _expiryDate,
                    _newExpiryDate,
                    _getProofSiblingsHash(proofSiblings),
                    uint256(KEYRING_VERSION)
                )
            );
    }

    function _getUpdateKeyOperatorDataHash(
        uint16 _keyringId,
        address _newOperator
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    UPDATE_KEY_OPERATOR_TYPEHASH,
                    _keyringId,
                    _newOperator,
                    uint256(KEYRING_VERSION)
                )
            );
    }

    function _getProofSiblingsHash(
        bytes32[] memory proofSiblings
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(proofSiblings));
    }
}
