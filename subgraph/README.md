# Panther Protocol Subgraph

This subgraph indexes Panther Protocol smart contract events for different environments.

## Prerequisites

- Node.js and yarn installed
- Graph CLI authentication token
- Required environment files (`.env.staging.internal`, `.env.staging.public`, `.env.canary.internal`)

## Setup

1. Install dependencies:
```bash
yarn install
```

2. Authenticate with Graph CLI:
```bash
yarn auth
```
When prompted, enter your Graph CLI authentication token.

## Environment Generation

Generate subgraph configuration for different environments:

### Staging Environment
- Internal testnet:
  ```bash
  yarn generate:staging:internal
  ```
- Public testnet:
  ```bash
  yarn generate:staging:public
  ```

### Canary Environment
- Internal network:
  ```bash
  yarn generate:canary:internal
  ```

## Building

After generating the environment configuration, build the subgraph:

```bash
yarn build
```

## Deployment

Deploy to different environments using the following commands:

### Staging Environment
- Internal testnet:
  ```bash
  yarn deploy:staging:internal
  ```
- Public testnet:
  ```bash
  yarn deploy:staging:public
  ```

### Canary Environment
- Internal network:
  ```bash
  yarn deploy:canary:internal
  ```

## Utilities

Count distinct protocol users via the subgraph:
```bash
yarn stats:count:users
```

## Environment Files

Make sure to create the following environment files with appropriate values:
- `.env.staging.internal`
- `.env.staging.public`
- `.env.canary.internal`

Each environment file should contain the necessary configuration variables for the respective network.

## Additional Resources

- [The Graph Documentation](https://thegraph.com/docs/en/)
- [Graph CLI Reference](https://github.com/graphprotocol/graph-cli)
