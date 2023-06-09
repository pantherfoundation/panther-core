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
    let resue = false;

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
        resue = true;
    }

    return resue;
}

export function fulfillLocalAddress(
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
    verifyUserConsentOnProd,
    upgradeEIP1967Proxy,
    setDeterministicDeploymentProxy,
    deployBytecodeDeterministically,
    deployContentDeterministically,
};
