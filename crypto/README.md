# Panther Protocol Cryptography Library

This package contains the core cryptographic primitives and utilities used throughout the Panther Protocol, including zero-knowledge proofs, Merkle trees, and other cryptographic operations.

## Overview

The cryptography library provides essential cryptographic operations for:

- Zero-knowledge proof generation and verification
- Merkle tree implementations (including Triad Merkle Tree)
- Cryptographic utilities for the Multi-Asset Shielded Pool (MASP)

## Prerequisites

- Node.js (v20 or higher)
- Yarn package manager

## Installation

```bash
yarn install
```

## Building

Build the library:

```bash
yarn build
```

This runs both type generation and TypeScript compilation:

- `yarn build:types` - Generates TypeScript type definitions
- `yarn build:ts` - Compiles TypeScript code

## Testing

Run the test suite:

```bash
yarn test
```

## Code Quality

Lint the code:

```bash
yarn lint
```

Fix linting issues:

```bash
yarn lint:fix
```

Format code:

```bash
yarn prettier:fix
```

## Browser Compatibility

This package is browser-compatible with the following Node.js modules disabled:

- fs
- path
- os

## License

See the LICENSE file in the root directory.

## Contributing

Please read our [Contributing Guidelines](../CONTRIBUTING.md) before submitting any pull requests.
