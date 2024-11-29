# Panther Protocol Smart Contracts

This workspace contains smart contracts, deployment scripts, Hardhat configuration tasks, and unit tests for the Panther Protocol.

## Prerequisites

- Node.js (v20 or higher)
- Yarn package manager
- Compiled crypto workspace (see [crypto README](../crypto/README.md) for instructions)
- Docker (optional, required for running Slither security analysis)

## Installation

```bash
yarn install
```

## Development

### Compile Contracts

```bash
yarn compile
```

### Clean

Remove artifacts and cache:

```bash
yarn clean
```

### Run Local Chain

Start a local Hardhat network:

```bash
yarn chain
```

### Testing

Run the full test suite:

```bash
yarn test
```

Run tests with gas reporting:

```bash
yarn test:gas
```

Generate test coverage:

```bash
yarn coverage
```

### Code Quality

Run all checks:

```bash
yarn full-check-before-commit
```

Lint code:

```bash
yarn lint
```

Format code:

```bash
yarn prettier:fix
```

### Security Analysis

Run Slither analysis:

```bash
yarn slither
```

Generate storage layout:

```bash
yarn storage
```

Generate UML diagrams:

```bash
yarn uml
```

## Deployment

### Supported Networks

- Mainnet (chainId: 1)
- Sepolia (chainId: 11155111)
- Polygon (chainId: 137)
- Amoy (chainId: 80002)

### Local Development

1. Deploy to local network:

```bash
yarn deploy:chain
```

### Protocol Deployment

Deploy protocol components:

```bash
yarn deploy:protocol
```

Deploy staking:

```bash
# Advanced staking
yarn deploy:staking:advanced

# Classic staking
yarn deploy:staking:classic
```

Deploy forest:

```bash
yarn deploy:forest
```

## Contract Verification

Configure environment:

- Copy `.env.example` to `.env`
- Add API keys:
  - `ETHERSCAN_API_KEY` for Ethereum networks
  - `POLYGONSCAN_API_KEY` for Polygon networks

Verify contracts:

```bash
yarn verify --network <network-name>
```

### Important Notes

- `PoseidonT3` and `PoseidonT4` contracts do not require verification
- For manual verification:

```bash
yarn hardhat verify <contract-address> <constructor-params> --network <network-name>
```

## Contributing

Please read our [Contributing Guidelines](../CONTRIBUTING.md) before submitting any pull requests.

## License

See the LICENSE file in the root directory.
