// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

import "../../../common/EIP712SignatureVerifier.sol";

abstract contract ProvidersKeysSignatureVerifier is EIP712SignatureVerifier {
    bytes32 internal constant REGISTRATION_TYPEHASH =
        keccak256(
            bytes(
                "Registration(uint32 keyringId,bytes32 pubRootSpendingKey,uint32 expiryDate,uint256 version)"
            )
        );

    uint8 public immutable KEYRING_VERSION;

    constructor(uint8 keyringVersion) {
        KEYRING_VERSION = keyringVersion;
    }

    function getRegistrationDataHash(
        uint32 _keyringId,
        bytes32 _pubRootSpendingKey,
        uint32 _expiryDate
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    REGISTRATION_TYPEHASH,
                    _keyringId,
                    _pubRootSpendingKey,
                    _expiryDate,
                    uint256(KEYRING_VERSION)
                )
            );
    }

    function recoverOperator(
        uint32 _keyringId,
        bytes32 _pubRootSpendingKey,
        uint32 _expiryDate,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 registrationDataHash = getRegistrationDataHash(
            _keyringId,
            _pubRootSpendingKey,
            _expiryDate
        );

        bytes32 typedDataHash = toTypedDataHash(registrationDataHash);

        return recover(typedDataHash, v, r, s);
    }
}
