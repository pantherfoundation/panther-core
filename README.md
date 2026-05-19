# Panther Protocol: core repository

This repository contains the heart of the Panther Protocol code, implementing privacy-preserving infrastructure for Web3 DeFi applications.

## Repository Structure

- [`contracts/`](contracts) - Smart contracts:
  - [`protocol/`](contracts/contracts/protocol) - Multi-Asset Shielded Pool (MASP):
    - `v1/pantherForest/` - Panther Forest Merkle tree implementation
    - `v1/pantherPool/` - Panther Pool core protocol contracts
  - [`staking/`](contracts/contracts/staking) - Staking contracts:
    - Classic staking implementation
    - Advanced staking implementation
  - [`common/`](contracts/contracts/common) - Shared utilities
- [`circuits/`](circuits) - Zero-knowledge circuits for privacy features
- [`crypto/`](crypto) - Core cryptographic primitives and utilities
- [`dapp/`](dapp) - Web-based dApp interface
- [`subgraph/`](subgraph) - Subgraph code for [The Graph](https://thegraph.com/en/)

## Prerequisites

This codebase requires expertise in:

- EVM chains, Solidity and Hardhat
- Zero Knowledge Proofs, circuits and cryptography
- React and Web3 development
- The Graph protocol

## Getting Started

1. Read the [Whitepaper](https://pantherprotocol.io/whitepaper) for high-level architecture
2. Read [overview documentation](docs/overview.md) for details on the UTXO model and cryptography
3. Set up development environment:
   - Node.js (v20 or higher)
   - Yarn package manager
   - Rust and Cargo (for circuits)
   - Circom (v2.0.5)
   - Docker (optional)

## Development

Each workspace has its own build and test procedures. See individual README files:

- [Circuits README](circuits/README.md)
- [Contracts README](contracts/README.md)
- [Crypto README](crypto/README.md)
- [Subgraph README](subgraph/README.md)
- [dApp README](dapp/README.md)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow our [Contributing Guidelines](CONTRIBUTING.md)
4. Submit a pull request

Key guidelines:

- Follow conventional commits standard
- Include workspace scope in commit messages
- Ensure all tests pass
- Update documentation as needed

## Community

- [Discord Server](https://discord.gg/WZuRnMCZ4c)
- [Web Forums](https://forum.pantherprotocol.io/)

## License

See individual LICENSE files in each workspace. If not explicitly marked, files should be considered unlicensed with no rights granted.
