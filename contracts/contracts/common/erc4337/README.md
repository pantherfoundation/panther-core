### ERC-4337 interfaces and imports

Contained within this folder are the essential account abstraction interfaces required to ensure compatibility with ERC-4337 protocol.

#### interfaces

Interfaces are borrowwd from https://github.com/eth-infinitism/account-abstraction/tree/develop/contracts/interfaces

#### EntryPoint

EntryPoint is used in tests to simulate bundler behaviour.
it also can be used by dApp to calculated and/or check the UserOperation nonce, as we use one smart account for all users.

#### UserOperation

UserOperation serves as the core data structure, housing the transactions intended for execution alongside other essential data.
