// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import assert from 'assert';

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {ethers} from 'ethers';
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import inq from 'inquirer';

function getContractEnvVariable(
    hre: HardhatRuntimeEnvironment,
    envWithoutNetworkSuffix: string,
) {
    return `${envWithoutNetworkSuffix}_${hre.network.name.toUpperCase()}`;
}

function getContractEnvAddress(
    hre: HardhatRuntimeEnvironment,
    envWithoutNetworkSuffix: string,
): string | undefined {
    const envKey = getContractEnvVariable(hre, envWithoutNetworkSuffix);
    const envValue = process.env[envKey];

    return envValue;
}

function reuseEnvAddress(
    hre: HardhatRuntimeEnvironment,
    envWithoutNetworkSuffix: string,
): boolean {
    const envKey = getContractEnvVariable(hre, envWithoutNetworkSuffix);
    const envValue = getContractEnvAddress(hre, envWithoutNetworkSuffix);
    let reuse = false;

    if (
        envValue &&
        ethers.utils.isAddress(envValue) &&
        envValue !== ethers.constants.AddressZero
    ) {
        console.log(
            '\x1b[32m',
            `Skip deployment. Using ${envKey} env variable`,
            envValue,
            '\x1b[0m',
        );
        reuse = true;
    }

    return reuse;
}

function fulfillLocalAddress(
    hre: HardhatRuntimeEnvironment,
    envWithoutNetworkSuffix: string,
) {
    const localNetworks = ['LOCALHOST', 'PCHAIN', 'HARDHAT'];

    let localAddress = '';

    localNetworks.every(network => {
        const env = process.env[`${envWithoutNetworkSuffix}_${network}`];
        if (env) {
            localAddress = env;
            return false;
        }

        return true;
    });

    if (!localAddress)
        throw Error(
            `No address found for ${envWithoutNetworkSuffix} env variable, Consider adding ${envWithoutNetworkSuffix}_LOCALHOST env variable`,
        );

    if (localNetworks.includes(hre.network.name.toUpperCase()))
        process.env[
            `${envWithoutNetworkSuffix}_${hre.network.name.toUpperCase()}`
        ] = localAddress;

    return localAddress;
}

function fulfillExistingContractAddresses(hre: HardhatRuntimeEnvironment) {
    if (hre.network.name === 'mainnet') fulfillMainnetAddresses(hre);
    if (hre.network.name === 'polygon') fulfillPolygonAddresses(hre);
    if (hre.network.name === 'goerli') fulfillGoerliAddresses(hre);
    if (hre.network.name === 'mumbai') fulfillMumbaiAddresses(hre);
}

function fulfillMainnetAddresses(hre: HardhatRuntimeEnvironment) {
    process.env[getContractEnvVariable(hre, 'FX_ROOT')] =
        '0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2';

    // Panther protocol contracts on mainnet
    process.env[getContractEnvVariable(hre, 'ZKP_TOKEN')] =
        '0x909E34d3f6124C324ac83DccA84b74398a6fa173';
    process.env[getContractEnvVariable(hre, 'VESTING_POOLS')] =
        '0xb476104aa9D1f30180a01987FB09b1e96dDCF14B';
    process.env[getContractEnvVariable(hre, 'STAKING')] =
        '0xf4d06d72dACdD8393FA4eA72FdcC10049711F899';
    process.env[getContractEnvVariable(hre, 'REWARD_MASTER')] =
        '0x347a58878D04951588741d4d16d54B742c7f60fC';
    process.env[getContractEnvVariable(hre, 'STAKE_REWARD_ADVISER')] =
        '0x5Df8Ec95d8b96aDa2B4041D639Ab66361564B050';
    process.env[getContractEnvVariable(hre, 'STAKE_REWARD_CONTROLLER_2')] =
        '0x1B316635a9Ed279995c78e5a630e13aaD7C0086b';
    process.env[getContractEnvVariable(hre, 'REWARD_POOL')] =
        '0xcF463713521Af5cE31AD18F6914f3706493F10e5';
    process.env[
        getContractEnvVariable(
            hre,
            'ADVANCED_STAKE_REWARD_ADVISER_AND_MSG_SENDER',
        )
    ] = '0xFED599513aB078Edea7Cf46574154f92b0B9FCAB';
    process.env[
        getContractEnvVariable(hre, 'ADVANCED_STAKE_V2_ACTION_MSG_TRANSLATOR')
    ] = '0x39ed49B3cEA4796E669f2542a41B876646c1BBe7';
}

function fulfillPolygonAddresses(hre: HardhatRuntimeEnvironment) {
    process.env[getContractEnvVariable(hre, 'FX_CHILD')] =
        '0x8397259c983751DAf40400790063935a11afa28a';

    // Panther protocol contracts on polygon
    process.env[getContractEnvVariable(hre, 'ZKP_TOKEN')] =
        '0x9A06Db14D639796B25A6ceC6A1bf614fd98815EC';
    process.env[getContractEnvVariable(hre, 'STAKING')] =
        '0x4cEc451F63DBE47D9dA2DeBE2B734E4CB4000Eac';
    process.env[getContractEnvVariable(hre, 'REWARD_MASTER')] =
        '0x09220DD0c342Ee92C333FAa6879984D63B4dff03';
    process.env[getContractEnvVariable(hre, 'STAKE_REWARD_ADVISER')] =
        '0xAa943954eB256cc8C170C1bacF538D65D9eb9069';
    process.env[getContractEnvVariable(hre, 'STAKE_REPORTER')] =
        '0x17f590df4Dd5000a223Cc08E31695cB83B181730';
    process.env[getContractEnvVariable(hre, 'STAKE_REWARD_CONTROLLER')] =
        '0xdCd54b9355F60A7B596D1B7A9Ac10E6477d6f1bb';
    process.env[getContractEnvVariable(hre, 'REWARD_TREASURY')] =
        '0x20AD9300BdE78a24798b1Ee2e14858E5581585Bc';
    process.env[getContractEnvVariable(hre, 'MATIC_REWARD_POOL')] =
        '0x773d49309c4E9fc2e9254E7250F157D99eFe2d75';
    process.env[getContractEnvVariable(hre, 'POSEIDON_T3')] =
        '0xA944DFafE9bcb0094A471E58206079c43ce0043D';
    process.env[getContractEnvVariable(hre, 'POSEIDON_T4')] =
        '0xf0FfB73D51d001024F6301a19c8A56488e9d2110';
    process.env[getContractEnvVariable(hre, 'VAULT_PROXY')] =
        '0x5E7Fda6d9f5024C4ad1c780839987aB8c76486c9';
    process.env[getContractEnvVariable(hre, 'VAULT_IMP')] =
        '0xd33B839Cd4f75b860dBF1662C25cfD1dC78B07Ba';
    process.env[getContractEnvVariable(hre, 'Z_ASSET_REGISTRY_PROXY')] =
        '0xb658B085144a0BEd098620BB829b676371B9B48c';
    process.env[getContractEnvVariable(hre, 'Z_ASSET_REGISTRY_IMP')] =
        '0x3F432d43E33B5CE9E10beE80f474394174f0E41D';
    process.env[getContractEnvVariable(hre, 'PANTHER_POOL_V0_PROXY')] =
        '0x9a423671e9Cde99Ae88853B701f98ca9e136877B';
    process.env[getContractEnvVariable(hre, 'PANTHER_POOL_V0_IMP')] =
        '0xD44bf566E132c6A8E49dD781f606123f9a6866C4';
    process.env[getContractEnvVariable(hre, 'PNFT_TOKEN')] =
        '0xE5da4955cBC480Eb9Bf9534def229F9D8339eE6d';
    process.env[
        getContractEnvVariable(hre, 'ADVANCED_STAKE_REWARD_CONTROLLER')
    ] = '0x8f15a43961c27C74CB4F55234A78802401614de3';
    process.env[
        getContractEnvVariable(hre, 'ADVANCED_STAKE_ACTION_MSG_RELAYER_PROXY')
    ] = '0x47374FBE2289c0442f33a388590385A0b32a20Ff';
    process.env[
        getContractEnvVariable(hre, 'ADVANCED_STAKE_ACTION_MSG_RELAYER_IMP')
    ] = '0x365882023e894C09F6bcC3F7c2fbb7fFF5b2512e';
    process.env[
        getContractEnvVariable(hre, 'ADVANCED_STAKE_V2_ACTION_MSG_TRANSLATOR')
    ] = '0x7f076D64055E19d0f9E84160748c6c3CED9c28aC';
}

function fulfillGoerliAddresses(hre: HardhatRuntimeEnvironment) {
    process.env[getContractEnvVariable(hre, 'FX_ROOT')] =
        '0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA';

    // Panther protocol contracts on mainnet
    process.env[getContractEnvVariable(hre, 'ZKP_TOKEN')] =
        '0x9a27804316F7b31110E3823b68578A821D144bA0';
    process.env[getContractEnvVariable(hre, 'ZKP_FAUCET')] =
        '0x720BEF9e9cceebd80e77460dEa5CaeD06D01Aa9D';
    process.env[getContractEnvVariable(hre, 'VESTING_POOLS')] =
        '0x1d5e02FBa32C9781AfdE40124ebeF54Ce8E8DCD5';
}

function fulfillMumbaiAddresses(hre: HardhatRuntimeEnvironment) {
    process.env[getContractEnvVariable(hre, 'FX_CHILD')] =
        '0xCf73231F28B7331BBe3124B907840A94851f9f11';

    // Panther protocol contracts on mainnet
    process.env[getContractEnvVariable(hre, 'ZKP_TOKEN')] =
        '0x3F73371cFA58F338C479928AC7B4327478Cb859f';
    process.env[getContractEnvVariable(hre, 'ZKP_FAUCET')] =
        '0xB79A02672bb45B5fFBE907b2aD1A5Ab84e151EC6';
}

async function getContractAddress(
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    envWithoutNetworkSuffix: string,
): Promise<string> {
    const contractAddress = getContractEnvAddress(hre, envWithoutNetworkSuffix);
    const contractAddressEnvVariable = getContractEnvVariable(
        hre,
        envWithoutNetworkSuffix,
    );

    try {
        return (
            contractAddress ||
            (await hre.ethers.getContract(deploymentName)).address
        );
    } catch (error: any) {
        console.log(
            '\x1b[31m',
            `Address for contract ${deploymentName} cannot be retrieved. Consider deploying a new version of this contract or adding a pre-deployed contract address in ${contractAddressEnvVariable} env variable`,
            '\x1b[0m',
        );

        throw new Error(error.message);
    }
}

async function upgradeEIP1967Proxy(
    hre: HardhatRuntimeEnvironment,
    signerAddress: string,
    proxyAddress: string,
    implementationAddress: string,
    contractNameForConsoleLogging = 'contract',
) {
    const {ethers} = hre;
    const eip1967ProxyAbi = [
        {
            inputs: [
                {
                    internalType: 'address',
                    name: 'newImplementation',
                    type: 'address',
                },
            ],
            name: 'upgradeTo',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
        },
    ];

    const proxy = await ethers.getContractAt(eip1967ProxyAbi, proxyAddress);

    const response = await ethers.provider.send('eth_getStorageAt', [
        proxy.address,
        // EIP-1967 implementation slot
        '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc',
    ]);

    const oldImpl: string = ethers.utils.hexZeroPad(
        ethers.utils.hexStripZeros(response),
        20,
    );

    if (oldImpl == implementationAddress.toLowerCase()) {
        console.log(
            '\x1b[32m',
            `Skip upgrading ${contractNameForConsoleLogging}. Proxy ${proxy.address} already set to Implementation: ${implementationAddress}`,
            '\x1b[0m',
        );
        return;
    }

    console.log(
        `Upgrading ${contractNameForConsoleLogging} Proxy ${proxy.address} to new Implementation: ${implementationAddress}...`,
    );

    const signer = await ethers.getSigner(signerAddress);
    const tx = await proxy.connect(signer).upgradeTo(implementationAddress);
    console.log('Proxy is upgraded, tx: ', tx.hash);
}

async function verifyUserConsentOnProd(
    hre: HardhatRuntimeEnvironment,
    signer: string,
) {
    if (hre.network.name === 'mainnet' || hre.network.name === 'polygon') {
        console.log(
            '\x1b[32m',
            `Using signer ${signer} to deploy on ${hre.network.name} network...`,
            '\x1b[0m',
        );

        const answer = await inq.prompt({
            type: 'confirm',
            name: 'question',
            message: 'Continue deploying the contract?',
            default: false,
        });
        if (!answer.question) {
            throw new Error('Signer was not confirmed');
        }
    }
}

function getDeterministicDeploymentProxyAddressAndCode() {
    // Using the deterministic-deployment-proxy contract from the Github repo:
    // https://github.com/Arachnid/deterministic-deployment-proxy
    const deployerAddr = '0x4e59b44847b379578588920cA78FbF26c0B4956C';
    const deployerCode =
        '0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3';

    return {deployerAddr, deployerCode};
}

async function setDeterministicDeploymentProxy(hre: HardhatRuntimeEnvironment) {
    const zeroCode = '0x';
    const hhSetCodeCommand = 'hardhat_setCode';

    const {deployerAddr, deployerCode} =
        getDeterministicDeploymentProxyAddressAndCode();

    const deployedCode = await hre.ethers.provider.getCode(deployerAddr);

    if (deployedCode == zeroCode) {
        await hre.ethers.provider.send(hhSetCodeCommand, [
            deployerAddr,
            deployerCode,
        ]);
        assert(
            (await hre.ethers.provider.getCode(deployerAddr)) == deployerCode,
            'Unexpected codes have been set',
        );
    } else if (deployedCode != deployerCode) {
        Error(`Unexpected code at ${deployerAddr}`);
    }
}

async function deployBytecodeDeterministically(
    hre: HardhatRuntimeEnvironment,
    bytecode: string,
    salt?: string,
    deployer?: SignerWithAddress,
): Promise<string> {
    const {deployerAddr, deployerCode} =
        getDeterministicDeploymentProxyAddressAndCode();

    const signer = deployer ? deployer : (await hre.ethers.getSigners())[0];
    const deploymentSalt = salt ? salt : hre.ethers.utils.id('salt');

    if ((await hre.ethers.provider.getCode(deployerAddr)) != deployerCode) {
        Error(`Unexpected d11cDeployer contract code at ${deployerAddr}`);
    }

    const callData = ethers.utils.solidityPack(
        ['bytes', 'bytes'],
        [deploymentSalt, bytecode],
    );

    const txData = {to: deployerAddr, data: callData};

    const address = await signer.call(txData);
    const tx = await signer.sendTransaction(txData);
    await tx.wait();

    return address;
}

async function deployContentDeterministically(
    hre: HardhatRuntimeEnvironment,
    content: string,
    salt?: string,
    deployer?: SignerWithAddress,
): Promise<string> {
    /**
     * @dev When called as the CONSTRUCTOR, this code skips 11 bytes of itself and returns
     * the rest of the "init code" (i.e. the "deployed code" that follows these 11 bytes):
     * | Bytecode | Mnemonic  | Stack View                                                    |
     * |----------|-----------|---------------------------------------------------------------|
     * | 0x600B   | PUSH1 11  | codeOffset                                                    |
     * | 0x59     | MSIZE     | 0 codeOffset                                                  |
     * | 0x81     | DUP2      | codeOffset 0 codeOffset                                       |
     * | 0x38     | CODESIZE  | codeSize codeOffset 0 codeOffset                              |
     * | 0x03     | SUB       | (codeSize - codeOffset) 0 codeOffset                          |
     * | 0x80     | DUP1      | (codeSize - codeOffset) (codeSize - codeOffset) 0 codeOffset  |
     * | 0x92     | SWAP3     | codeOffset (codeSize - codeOffset) 0 (codeSize - codeOffset)  |
     * | 0x59     | MSIZE     | 0 codeOffset (codeSize - codeOffset) 0 (codeSize - codeOffset)|
     * | 0x39     | CODECOPY  | 0 (codeSize - codeOffset)                                     |
     * | 0xf3     | RETURN    | -                                                             |
     *
     * @dev Deployed bytecode starts with this HEADER to prevent calling the bytecode
     * | Bytecode | Mnemonic  | Stack View                                                    |
     * |----------|-----------|---------------------------------------------------------------|
     * | 0x00     | STOP      | -                                                             |
     */
    const constructorAndHeader = '0x600B5981380380925939F300';

    const data = ethers.utils.solidityPack(
        ['bytes', 'bytes'],
        [constructorAndHeader, content],
    );

    const pointer = deployBytecodeDeterministically(hre, data, salt, deployer);

    assert(
        (await hre.ethers.provider.getCode(pointer)) ==
            '0x00' + content.replace('0x', ''),
        `Unexpected deployed code at ${pointer}`,
    );

    return pointer;
}

export {
    reuseEnvAddress,
    getContractAddress,
    getContractEnvAddress,
    getContractEnvVariable,
    fulfillLocalAddress,
    fulfillExistingContractAddresses,
    verifyUserConsentOnProd,
    upgradeEIP1967Proxy,
    setDeterministicDeploymentProxy,
    deployBytecodeDeterministically,
    deployContentDeterministically,
};
