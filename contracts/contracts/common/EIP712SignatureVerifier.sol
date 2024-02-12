// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

abstract contract EIP712SignatureVerifier {
    bytes private constant EIP191_VERSION = "\x19\x01";

    string public constant EIP712_NAME = "Panther Protocol";
    string public constant EIP712_VERSION = "1";

    // keccak256(bytes("PANTHER_EIP712_DOMAIN_SALT"));
    bytes32 public constant EIP712_SALT =
        0x44b818e3e3a12ecf805989195d8f38e75517386006719e2dbb1443987a34db7b;

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            bytes(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
            )
        );

    function getDomainSeperator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(EIP712_NAME)),
                    keccak256(bytes(EIP712_VERSION)),
                    block.chainid,
                    address(this),
                    EIP712_SALT
                )
            );
    }

    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address signer) {
        signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA invalid signature");
    }

    function toTypedDataHash(
        bytes32 structHash
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    EIP191_VERSION,
                    getDomainSeperator(),
                    structHash
                )
            );
    }
}
