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

import './tasks/test-proposal.ts';
import './tasks/test-ethereum-txs.ts';
import './tasks/pip-38-proposal.ts';
import './tasks/pip-38-test-ethereum.ts';
import './tasks/get-deployment-addresses.ts';
import './tasks/protocol/grant-issue';
import './tasks/protocol/pool-time-update.ts';
import './tasks/protocol/pubkey-register';
import './tasks/protocol/uniswap-router-plugin-swap.ts';
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
    base: 8453,
    basesepolia: 84532,
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

    base: 'https://base-mainnet.g.alchemy.com/v2/',
    basesepolia: 'https://base-sepolia.g.alchemy.com/v2/',
};

const INFURA_ENDPOINTS: {[name: string]: string} = {
    mainnet: 'https://mainnet.infura.io/v3/',
    sepolia: 'https://sepolia.infura.io/v3/',

    polygon: 'https://polygon-mainnet.infura.io/v3/',
    amoy: 'https://polygon-amoy.infura.io/v3/',

    base: 'https://base-mainnet.infura.io/v3/',
    basesepolia: 'https://base-sepolia.infura.io/v3/',
};

const forkingConfig: {url: string; enabled: boolean; blockNumber?: number} = {
    url: process.env.HARDHAT_FORKING_URL || 'ts compiler hack',
    enabled: !!process.env.HARDHAT_FORKING_ENABLED,
};

if (process.env.HARDHAT_FORKING_BLOCK) {
    forkingConfig.blockNumber = Number(process.env.HARDHAT_FORKING_BLOCK);
}

const config: HardhatUserConfig = {
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            forking: process.env.HARDHAT_FORKING_URL
                ? forkingConfig
                : undefined,
            chainId: parseInt(process.env.HARDHAT_CHAIN_ID || '31337'),
            allowUnlimitedContractSize: true,
            chains: {
                137: {
                    hardforkHistory: {
                        london: 0,
                    },
                },
            },
        },
        pchain: {url: 'http://127.0.0.1:8545'},

        mainnet: createNetworkConfig('mainnet'),
        sepolia: createNetworkConfig('sepolia'),

        polygon: createNetworkConfig('polygon'),
        amoy: createNetworkConfig('amoy'),

        base: createNetworkConfig('base'),
        basesepolia: createNetworkConfig('basesepolia'),
    },
    etherscan: {
        // Etherscan V2 unified API: a single etherscan.io key verifies on
        // every supported chain (Ethereum, Polygon, Base, ...). `base` and
        // `baseSepolia` are built into hardhat-verify, so no customChains
        // entry is needed for them.
        apiKey: process.env.ETHERSCAN_API_KEY as string,
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

            base: 0,
            basesepolia: 0,
        },

        multisig: {
            localhost: 0,
            hardhat: 0,
            mainnet: '0x505796f5Bc290269D2522cf19135aD7Aa60dfd77',
            sepolia: 0,

            polygon: '0x026a024b13B4Ca23897ad578264C0ec543f904b9',
            amoy: 0,

            base: '0xb16283a233d5b010a7b290d593847207495f0284',
            basesepolia: 0,
        },

        trustProvider: {
            localhost: 0,
            hardhat: 0,
            mainnet: '0x505796f5Bc290269D2522cf19135aD7Aa60dfd77', // TODO: replace
            sepolia: 0,

            polygon: '0x781E4F7f41779d8b8bED1bA0b32D4BBB87d8194D', //* Purify
            amoy: 0,

            base: 0, // TODO: replace
            basesepolia: 0,
        },

        treasuryClaimer: {
            localhost: 0,
            hardhat: 0,
            mainnet: '0x505796f5Bc290269D2522cf19135aD7Aa60dfd77', // TODO: replace
            sepolia: 0,

            polygon: '0xE454ba38c6d358c8018dFA2cBA9a6096B2420ECD',
            amoy: 0,

            base: '0xb16283a233d5b010a7b290d593847207495f0284', // TODO: replace
            basesepolia: 0,
        },

        zkp: {
            localhost: 0,
            hardhat: 0,
            mainnet: '0x909E34d3f6124C324ac83DccA84b74398a6fa173',
        },

        pzkp: {
            localhost: 0,
            hardhat: 0,
            amoy: '0xCd85e3E918F1A36F939281d3ca707EE262a364c6',
            polygon: '0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC',
            base: '0x0a776C1c22b8b8e7EAB346744dAA33722b80FdA4',
        },

        weth9: {
            localhost: 0,
            hardhat: 0,
            sepolia: '0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14',
            amoy: '0x360ad4f9a9A8EFe9A8DCB5f461c4Cc1047E1Dcf9',
            polygon: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
            base: '0x4200000000000000000000000000000000000006',
        },

        link: {
            localhost: 0,
            hardhat: 0,
            amoy: '0xA82B5942DD61949Fd8A2993dCb5Ae6736F8F9E60',
            polygon: '0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39',
        },

        uniswapRouter: {
            localhost: 0,
            hardhat: 0,
            amoy: '0x4832EEB61E08A4fdCABDBD5d7ea131A7b82714b2',
            polygon: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
            base: '0x2626664c2603336E57B271c5C0b26F421741e481',
        },

        uniswapQuoterV2: {
            localhost: 0,
            hardhat: 0,
            amoy: '0x45878FFf4F23118805161e931FB39BA32416A3ba',
            polygon: '0x61fFE014bA17989E743c5F6cB21bF9697530B21e',
            base: '0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a',
        },

        quickswapRouter02: {
            localhost: 0,
            hardhat: 0,
            amoy: '0xf253c47dcD36Ab80BAB5731f548fd818551f1c16',
            polygon: '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff',
            base: '0x4a012af2b05616Fb390ED32452641C3F04633bb5',
        },

        quickswapFactory: {
            localhost: 0,
            hardhat: 0,
            amoy: '0x4583899E08a5707B777a7730C7C099D355C330B3',
            polygon: '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32',
            base: '0xEC6540261aaaE13F236A032d454dc9287E52e56A',
        },

        pZkp_native_uniswapV3Pool: {
            localhost: 0,
            hardhat: 0,
            amoy: '0x201124282bed388550c83BCF083e65dc49368EB8',
            polygon: '0xED151A7637EC45375EB6E39FC596E53CE6ED51FE',
        },

        pZkp_link_uniswapV3Pool: {
            localhost: 0,
            hardhat: 0,
            amoy: '0xdD556a7f6a88d2dA7d5C7d4c16337C62B34B2dCb',
            polygon: 0,
        },

        link_native_uniswapV3Pool: {
            localhost: 0,
            hardhat: 0,
            amoy: '0xd61679A9cD1152bdfA9Ce2ff78ebd8bE67314935',
            polygon: '0x0A28C2F5E0E8463E047C203F00F649812AE67E4F',
        },
        entryPoint: {
            amoy: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
            polygon: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
            base: '0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789',
        },

        uniswapV3NonfungiblePositionManager: {
            amoy: '',
        },
        uniswapV3Factory: {
            amoy: '',
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
    if (network === 'amoy') return 'https://rpc-amoy.polygon.technology/';
    if (network === 'base') return 'https://mainnet.base.org';
    if (network === 'basesepolia') return 'https://sepolia.base.org';
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
