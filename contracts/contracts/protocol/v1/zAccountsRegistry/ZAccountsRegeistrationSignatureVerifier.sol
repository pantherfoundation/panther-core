// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../../common/EIP712SignatureVerifier.sol";

abstract contract ZAccountsRegeistrationSignatureVerifier is
    EIP712SignatureVerifier
{
    bytes32 internal constant REGISTRATION_TYPEHASH =
        keccak256(
            bytes(
                "Registration(bytes32 pubRootSpendingKey,bytes32 pubReadingKey,uint256 version)"
            )
        );

    uint8 public immutable ZACCOUNT_VERSION;

    constructor(uint8 zAccountVersion) {
        ZACCOUNT_VERSION = zAccountVersion;
    }

    function getRegistrationDataHash(
        bytes32 _pubRootSpendingKey,
        bytes32 _pubReadingKey
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    REGISTRATION_TYPEHASH,
                    _pubRootSpendingKey,
                    _pubReadingKey,
                    uint256(ZACCOUNT_VERSION)
                )
            );
    }

    function recoverMasterEoa(
        bytes32 _pubRootSpendingKey,
        bytes32 _pubReadingKey,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 registrationDataHash = getRegistrationDataHash(
            _pubRootSpendingKey,
            _pubReadingKey
        );

        bytes32 typedDataHash = toTypedDataHash(registrationDataHash);

        return recover(typedDataHash, v, r, s);
    }
}
