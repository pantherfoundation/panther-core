// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2023 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

abstract contract ZAccountRegeistrationSignatureVerifier {
    string public constant ERC712_VERSION = "1";
    string public constant ERC712_NAME = "ZAccountsRegistry";

    uint8 public constant ZACCOUNT_VERSION = 0x01;

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            bytes(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
            )
        );
    bytes32 internal constant REGISTRATION_TYPEHASH =
        keccak256(
            bytes(
                "Registration(bytes32 pubRootSpendingKey,bytes32 pubReadingKey,uint256 version)"
            )
        );

    function getDomainSeperator(bytes32 _salt) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(ERC712_NAME)),
                    keccak256(bytes(ERC712_VERSION)),
                    _getChainId(),
                    address(this),
                    _salt
                )
            );
    }

    function getRegisteration(
        bytes32 _pubRootSpendingKey,
        bytes32 _pubReadingKey
    ) public view returns (bytes32) {
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

    function toTypedMessageHash(
        bytes32 _salt,
        bytes32 _pubRootSpendingKey,
        bytes32 _pubReadingKey
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    getDomainSeperator(_salt),
                    getRegisteration(_pubRootSpendingKey, _pubReadingKey)
                )
            );
    }

    function verifySignature(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address signer) {
        signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "invalid signature");
    }

    function _getChainId() private view returns (uint256) {
        uint256 id;

        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            id := chainid()
        }
        // solhint-enable no-inline-assembly

        return id;
    }
}
