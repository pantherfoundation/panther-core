# Panther Protocol Circuits

This workspace contains the zero-knowledge circuits used in the Panther Protocol, including circuits for transactions, account management, and AMM operations.

## Prerequisites

- Node.js (v20 or higher)
- Yarn package manager
- Rust
- Cargo
- Circom (v2.0.5)
- Docker (optional)

For detailed Circom installation instructions, see the [official documentation](https://docs.circom.io/getting-started/installation/).

**Note:** These circuits are built with Circom v2.0.5. Using newer versions may result in compilation errors due to stricter rules.

## Installation

```bash
yarn install
```

## Development

### Building

Build TypeScript and generate types:
```bash
yarn build
```

### Circuit Compilation

Compile all main circuits:
```bash
yarn compile:main-everything
```

Individual circuit compilation:
```bash
# AMM circuit
yarn compile:main-amm

# Transaction circuit
yarn compile:main-z-transaction

# Account registration
yarn compile:main-z-account-registration

# Account renewal
yarn compile:main-z-account-renewal

# Swap circuit
yarn compile:main-z-swap

# Tree batch updater
yarn compile:main-tree-batch-updater-and-root-checker
```

### Circuit Inspection

Inspect circuits for debugging:
```bash
yarn inspect:main-everything
```

### Security Analysis

Run Circomspect analysis:
```bash
yarn circomspect:everything
```

### Testing

Run all tests:
```bash
yarn test
```

Run TypeScript tests only:
```bash
yarn test:only-ts
```

Run extended tests:
```bash
yarn test:long
```

Docker-based testing:
```bash
yarn test:docker
```

### Code Quality

Lint code:
```bash
yarn lint
```

Format code:
```bash
yarn prettier:fix
```

## Docker Support

For Docker-based compilation:
```bash
yarn compile:main-z-transaction-docker
```

## Contributing

Please read our [Contributing Guidelines](../CONTRIBUTING.md) before submitting any pull requests.

## License

See the LICENSE file in the root directory.
