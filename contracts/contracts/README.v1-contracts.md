# Panther Protocol V1 Smart Contracts

This repository contains the smart contracts that power Panther Protocol's V1 version. Below is a detailed description of the key contracts and their roles within the protocol.

## Account Smart Contract

File: contracts/protocol/v1/Account.sol

The Account contract is Panther Protocol's implementation of the ERC-4337 "Account Contract." It is a singleton, meaning there is a single instance used by all protocol users, running without a proxy. This contract has no "owner" role and grants no special privileges to other contracts or accounts.

## FeeMaster Smart Contract

File:

    Implementation: contracts/protocol/v1/FeeMaster.sol
    Proxy: contracts/common/proxy/EIP173Proxy.sol

FeeMaster is the central hub for managing fees and reserves within Panther Protocol. It is a singleton contract running behind an EIP173Proxy. The "owner" role in this contract has the authority to configure it, and the "Protocol Owner" is expected to be the owner. This contract interacts with various others, such as the Vault and the "treasury," each with its specialized role.

## PantherPoolV1 Smart Contract

File:

    Proxy: contracts/protocol/v1/PantherPoolV1.sol
    Implementations: contracts/protocol/v1/core/facets/*.sol

PantherPoolV1 implements the core functionality of the Multi-Asset Shielded Pool (MASP), a key component of Panther Protocol. It operates as a "Diamond" proxy (./diamond/Diamond.sol), with its facets located in the ./core/facets/ folder. The contract includes an "owner" role for managing parameters, with the "Protocol Owner" acting as the owner. The proxy contract is also the owner of the Vault contract.

## PantherTrees Smart Contract

File:

    Proxy: contracts/protocol/v1/PantherTrees.sol
    Implementations: contracts/protocol/v1/trees/facets/*.sol

PantherTrees manages a set of Merkle Trees that store UTXOs (via the ForestTrees facet) and MASP configuration parameters (via the StaticTree facet). Like PantherPoolV1, it operates as a "Diamond" proxy, with its facets located in the ./trees/facets/ folder. Only the PantherPool role (held by the PantherPoolV1 proxy) can modify the trees. The "owner" role can update configuration parameters, with the "Protocol Owner" serving as the owner.

## PayMaster Smart Contract

File:

    Implementation: contracts/protocol/v1/PayMaster.sol
    Proxy: contracts/common/proxy/EIP173ProxyWithReceive.sol

PayMaster is Panther Protocol's implementation of the ERC-4337 "Paymaster" contract, which sponsors user transactions sent via external bundlers through the Account contract. It is reimbursed by the FeeMaster contract. The PayMaster contract runs behind the EIP173ProxyWithReceive proxy, and the "Protocol Owner" has control over upgrades and configuration updates.

## VaultV1 Smart Contract

File:

    Implementation: contracts/protocol/v1/VaultV1.sol
    Proxy: contracts/common/proxy/EIP173ProxyWithReceive.sol

VaultV1 is responsible for locking and unlocking assets deposited in the MASP, handling the transfer of assets between users and itself. Only the PantherPoolV1 contract, which serves as the sole owner, is authorized to trigger asset transfers. The contract runs behind the EIP173ProxyWithReceive proxy.

## ZkpReserveController Smart Contract

File: contracts/protocol/v1/ZkpReserveController.sol

ZkpReserveController contract releases ZKP tokens to the PRP/ZKP pool (PRPConversion contract) in a linear fashion. Users who trigger a release exceeding a set reward threshold are rewarded with PRP tokens through the PRPVoucherGrantor contract.

## QuickswapRouterPlugin Smart Contract

File: contracts/protocol/v1/plugins/quickswap/QuickswapRouterPlugin.sol
A plugin that integrates Panther Protocol with Quickswap.

## UniswapV3RouterPlugin Smart Contract

File: contracts/protocol/v1/plugins/uniswapV3/UniswapV3RouterPlugin.sol
A plugin that integrates Panther Protocol with Uniswap V3.

## EIP173Proxy Smart Contract

File: contracts/common/proxy/EIP173Proxy.sol
A proxy contract compatible with the EIP-173 standard. Multiple contracts in Panther Protocol run behind instances of this proxy.

## EIP173ProxyWithReceive Smart Contract

File: contracts/common/proxy/EIP173ProxyWithReceive.sol
An extension of the EIP173Proxy that allows the contract to receive native tokens (e.g., Ether). Several contracts in Panther Protocol utilize this proxy.
