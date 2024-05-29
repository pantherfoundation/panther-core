# Panther Protocol circuits

**Note:** This is a WIP document.

This repository contains circom circuits, scripts facilitating the circom compilation and unit tests for circom circuits.

## Prerequisite Installations

- Rust
- Node.js
- Cargo
- Docker (optional)

Complete installation guide is available
[here](https://docs.circom.io/getting-started/installation/ 'Circom installation page').

**Note:** Present circom circuits are built on circom version 2.0.1, so it is recommended to use the same version. The newer versions of circom introduce more stricter compilation rules so you might get compilation errors.

## Compiling Circom files

Run the following command to compile the circom files

`yarn compile`

This should output corresponding set of files (ex: _.js, _.wasm) inside compiled folder.

## Running unit test cases

Run the following command to transpile typescript files and also to build types.

`yarn build`

This should populate types/_ and lib/_ folder.

Upon successful build, run the following command to run the test cases for circom files. This command runs the test cases in local environment.

`yarn test`

To run test cases in docker environment run the following command

`yarn test:docker`
