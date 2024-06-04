// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {resolve} from 'path';

import '@nomicfoundation/hardhat-chai-matchers';
import '@nomicfoundation/hardhat-verify';
import '@nomiclabs/hardhat-ethers';
import '@typechain/hardhat';
import {config as dotenvConfig} from 'dotenv';
import {HardhatUserConfig} from 'hardhat/config';
import {NetworkUserConfig, HttpNetworkAccountsUserConfig} from 'hardhat/types';
import 'hardhat-contract-sizer';
import 'hardhat-deploy';
import 'hardhat-gas-reporter';
import 'solidity-coverage';

import './tasks/protocol/grant-issue';
import './tasks/protocol/pool-time-update.ts';
import './tasks/protocol/pubkey-register';
import './tasks/protocol/zAsset-add';
import './tasks/staking/commitments-list';
import './tasks/staking/matic-reward-pool-init';
import './tasks/staking/proposal-gen';
import './tasks/staking/reward-adviser-add';
import './tasks/staking/reward-params-update';
import './tasks/staking/reward-pool-init';
import './tasks/staking/rewards-limit-add';
import './tasks/staking/staking-add-stake';
import './tasks/staking/staking-bridge-local';
import './tasks/staking/staking-list';
import './tasks/staking/terms-add';
import './tasks/staking/terms-add-advanced-local';
import './tasks/staking/terms-update';
import './tasks/staking/time-increase';
import './tasks/staking/unstaked-rewards';
import './tasks/staking/vesting-list';

dotenvConfig({path: resolve(__dirname, './.env')});

type NetworkName = string;

const CHAIN_IDS: {[name: string]: number} = {
    mainnet: 1,
    sepolia: 11155111,
    polygon: 137,
    amoy: 80002,
    bsc: 56,
    bsctest: 97,
    ganache: 1337,
    hardhat: 31337,
};

const ALCHEMY_ENDPOINTS: {[name: string]: string} = {
    mainnet: 'https://eth-mainnet.g.alchemy.com/v2/',
    sepolia: 'https://eth-sepolia.g.alchemy.com/v2/',

    polygon: 'https://polygon-mainnet.g.alchemy.com/v2/',
    amoy: 'https://polygon-amoy.g.alchemy.com/v2/',
};

const INFURA_ENDPOINTS: {[name: string]: string} = {
    mainnet: 'https://mainnet.infura.io/v3/',
    sepolia: 'https://sepolia.infura.io/v3/',

    polygon: 'https://polygon-mainnet.infura.io/v3/',
    amoy: 'https://polygon-amoy.infura.io/v3/',
};

const forkingConfig = {
    url: process.env.HARDHAT_FORKING_URL || 'ts compiler hack',
    blockNumber: Number(process.env.HARDHAT_FORKING_BLOCK),
    enabled: !!process.env.HARDHAT_FORKING_ENABLED,
};

const config: HardhatUserConfig = {
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            forking: process.env.HARDHAT_FORKING_URL
                ? forkingConfig
                : undefined,
            chainId: parseInt(process.env.HARDHAT_CHAIN_ID || '31337'),
            allowUnlimitedContractSize: true,
        },
        pchain: {url: 'http://127.0.0.1:8545'},

        mainnet: createNetworkConfig('mainnet'),
        sepolia: createNetworkConfig('sepolia'),

        polygon: createNetworkConfig('polygon'),
        amoy: createNetworkConfig('amoy'),
    },
    etherscan: {
        apiKey: {
            mainnet: process.env.ETHERSCAN_API_KEY as string,
            sepolia: process.env.ETHERSCAN_API_KEY as string,
            polygon: process.env.POLYGONSCAN_API_KEY as string,
            amoy: process.env.POLYGONSCAN_API_KEY as string,
        },
        customChains: [
            createEtherscanConfig('amoy', {
                apiURL: 'https://api-amoy.polygonscan.com/api',
                browserURL: 'https://amoy.polygonscan.com',
            }),
        ],
    },
    sourcify: {
        // setting to false to hide INFO message in console when verifying.
        enabled: false,
    },
    // @ts-ignore
    gasReporter: {
        currency: 'USD',
        ...(process.env.CMC_API_KEY
            ? {coinmarketcap: process.env.CMC_API_KEY}
            : {}),

        enabled: !!process.env.REPORT_GAS,
        excludeContracts: [],
        src: './contracts',
    },
    mocha: {
        timeout: 2000000000,
    },
    // @ts-ignore
    namedAccounts: getNamedAccounts(),
    paths: {
        artifacts: './artifacts',
        cache: './cache',
        sources: './contracts',
        tests: './test',
    },
    solidity: {
        compilers: [
            {
                version: '0.7.6',
                settings: {
                    metadata: {
                        // do not include the metadata hash, since this is machine dependent
                        // and we want all generated code to be deterministic
                        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
                        bytecodeHash: 'none',
                    },
                    // You should disable the optimizer when debugging
                    // https://hardhat.org/hardhat-network/#solidity-optimizer-support
                    optimizer: {
                        enabled: true,
                        runs: 800,
                    },
                },
            },
            {
                version: '0.8.4',
                settings: {
                    metadata: {
                        // Not including the metadata hash
                        // https://github.com/paulrberg/solidity-template/issues/31
                        bytecodeHash: 'none',
                    },
                    // You should disable the optimizer when debugging
                    // https://hardhat.org/hardhat-network/#solidity-optimizer-support
                    optimizer: {
                        enabled: true,
                        runs: 800,
                    },
                    outputSelection: {
                        '*': {
                            '*': ['storageLayout'],
                        },
                    },
                },
            },
            {
                version: '0.8.16',
                settings: {
                    metadata: {
                        // Not including the metadata hash
                        // https://github.com/paulrberg/solidity-template/issues/31
                        bytecodeHash: 'none',
                    },
                    // You should disable the optimizer when debugging
                    // https://hardhat.org/hardhat-network/#solidity-optimizer-support
                    optimizer: {
                        enabled: true,
                        runs: 800,
                    },
                    outputSelection: {
                        '*': {
                            '*': ['storageLayout'],
                        },
                    },
                },
            },
            {
                version: '0.8.19',
                settings: {
                    metadata: {
                        // Not including the metadata hash
                        // https://github.com/paulrberg/solidity-template/issues/31
                        bytecodeHash: 'none',
                    },
                    // You should disable the optimizer when debugging
                    // https://hardhat.org/hardhat-network/#solidity-optimizer-support
                    optimizer: {
                        enabled: true,
                        runs: 800,
                    },
                    outputSelection: {
                        '*': {
                            '*': ['storageLayout'],
                        },
                    },
                },
            },
        ],
        overrides: {
            'contracts/contracts/common/proxy/EIP173Proxy.sol': {
                // Same as the `hardhat-deploy` plugin (v.0.11.4) applies
                version: '0.8.10',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 999999,
                    },
                },
            },
        },
    },
    typechain: {
        outDir: 'types/contracts',
        target: 'ethers-v5',
    },
};

function getNamedAccounts() {
    const namedAccounts = {
        deployer: {
            localhost: 0, // here this will by default take the first account as deployer
            hardhat: 0, // here this will by default take the first account as deployer
            mainnet: 0,
            sepolia: 0,

            polygon: 0,
            amoy: 0,
        },

        multisig: {
            localhost: 0,
            hardhat: 0,
            mainnet: '0x505796f5Bc290269D2522cf19135aD7Aa60dfd77',
            sepolia: 0,

            polygon: '0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0',
            amoy: 0,
        },

        zkp: {
            mainnet: '0x909E34d3f6124C324ac83DccA84b74398a6fa173',
        },
        pzk: {
            polygon: '0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC',
        },
        weth9: {
            sepolia: '0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14',
            amoy: '0x360ad4f9a9A8EFe9A8DCB5f461c4Cc1047E1Dcf9',
        },
    };

    return namedAccounts;
}

function getAccounts(network: string): HttpNetworkAccountsUserConfig {
    if (process.env.PRIVATE_KEY) {
        return [process.env.PRIVATE_KEY];
    }
    return {
        count: 5,
        initialIndex: 0,
        mnemonic: getMnemonic(network),
        path: "m/44'/60'/0'/0",
    };
}

function createNetworkConfig(
    network: string,
    extraOpts = {},
): NetworkUserConfig {
    return Object.assign(
        {
            accounts: getAccounts(network),
            // @ts-ignore
            chainId: CHAIN_IDS[network],
            timeout: 99999,
            url: getRpcUrl(network),
        },
        extraOpts,
    );
}

function createEtherscanConfig(
    network: string,
    urls: {apiURL: string; browserURL: string},
) {
    const {apiURL, browserURL} = urls;

    return Object.assign({
        network,
        chainId: CHAIN_IDS[network],
        urls: {
            apiURL,
            browserURL,
        },
    });
}

function getRpcUrl(network: NetworkName): string {
    if (!!process.env.HTTP_PROVIDER) return process.env.HTTP_PROVIDER;
    if (process.env.INFURA_API_KEY && INFURA_ENDPOINTS[network])
        return INFURA_ENDPOINTS[network] + process.env.INFURA_API_KEY;
    if (process.env.ALCHEMY_API_KEY && ALCHEMY_ENDPOINTS[network])
        return ALCHEMY_ENDPOINTS[network] + process.env.ALCHEMY_API_KEY;
    if (network === 'bsc') return 'https://bsc-dataseed1.defibit.io/';
    if (network === 'bsctest')
        return 'https://data-seed-prebsc-1-s1.binance.org:8545';
    if (network === 'polygon') return 'https://polygon-rpc.com/';
    return 'undefined RPC provider URL';
}

function getMnemonic(network: NetworkName): string {
    if (process.env.HARDHAT_NO_MNEMONIC) {
        // dummy mnemonic
        return 'any pig at zoo eat toy now ten men see job run';
    }
    if (process.env.MNEMONIC) return process.env.MNEMONIC;
    try {
        return require('./mnemonic.js');
    } catch (error) {
        throw new Error(`Please set your MNEMONIC (for network: ${network})`);
    }
}

export default config;
