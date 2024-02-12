// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

/***
  @titile StealthEthPull library
  @notice Library to "pull" the entire ETH balance from a deterministic "stealth" account.

  @dev In order to "pull" ETH from a deterministically defined address, it deploys at that
  address the "SelfDestructor" contract. The later self-destructs, causing transfer of ETH
  (remained before the deployment) from that address to the "deployer".
  The SelfDestructor is not a "normal" contract - it "vanishes" during its deployment. It
  has no runtime code at all. Its creation code (init code) does nothing but self-destroys
  own context. The context destruction causes the transfer, which is the sole purpose of
  the SelfDestructor "deployment".
  Thanks to CREATE2 invoking the creation code, the SelfDestructor address may be computed
  in advance.
  */
library StealthEthPull {
    uint256 private constant ZERO_ETH = 0;

    /// @dev Pull to the msg.sender the ETH balance from the address defined by the salt
    /// @param salt The salt (that deterministically derives the "from" address)
    /// @return The address the ETH balance is pulled from
    function stealthPullEthBalance(bytes32 salt) internal returns (address) {
        bytes memory initCode = _getSelfDestructorInitCode();
        // Execute `initCode` in the context of the newly created contract
        return Create2.deploy(ZERO_ETH, salt, initCode);
    }

    /// @dev Compute the address, defined by the salt, the ETH balance is pulled from
    /// (`this` contract is assumed to call `function stealthPullEthBalance`)
    /// @param salt The salt (that deterministically derives the "from" address)
    function getStealthAddr(bytes32 salt) internal view returns (address) {
        return _getStealthAddr(salt, address(this));
    }

    /// @dev Compute the address, defined by the salt, the ETH balance is pulled from
    /// (`deployer` address is assumed to call `function stealthPullEthBalance`)
    /// @param salt The salt (that deterministically derives the "from" address)
    function getStealthAddr(
        bytes32 salt,
        address deployer
    ) internal pure returns (address) {
        return _getStealthAddr(salt, deployer);
    }

    // It returns the creation code (init code) of the SelfDestructor "contract".
    // This creation code is to be invoked via the `CREATE2` opcode (`CREATE` works
    // also, but the SelfDestructor address can't be computed upfront then).
    // Being invoked, the creation code does nothing but executes the `SELFDESTRUCT`,
    // which moves the ETH balance from the SelfDestructor address to the contract that
    // invokes the creation code (i.e. calls the `CREATE2`).
    function _getSelfDestructorInitCode() private pure returns (bytes memory) {
        // =Bytecode   =Opcode
        // 33          CALLER
        // FF          SELFDESTRUCT
        // 00          STOP
        return hex"33ff00";
    }

    function _getStealthAddr(
        bytes32 salt,
        address deployer
    ) private pure returns (address) {
        bytes32 initCodeHash = keccak256(_getSelfDestructorInitCode());
        return Create2.computeAddress(salt, initCodeHash, deployer);
    }
}
