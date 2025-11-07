// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    getContractEnvVariable,
    getNamedAccount,
    upgradeEIP1967ProxyAndCall,
    verifyUserConsentOnProd,
} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, ethers} = hre;
    const {deploy, save} = deployments;

    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const treasuryOwner = await getNamedAccount(hre, 'pantherTreasury');
    const zkpToken = await getNamedAccount(hre, 'pzkp');

    const signersKey = getContractEnvVariable(hre, 'CLAIM_TREASURY_SIGNERS');
    const thresholdKey = getContractEnvVariable(
        hre,
        'CLAIM_TREASURY_THRESHOLD',
    );

    const signerCsv = process.env[signersKey] || '';
    const rawSigners = signerCsv
        .split(',')
        .map(value => value.trim())
        .filter(value => value.length != 0);

    const signers =
        rawSigners.length != 0 ? rawSigners : [treasuryOwner ?? multisig];

    const normalizedSigners: string[] = [];
    for (const signer of signers) {
        if (!ethers.utils.isAddress(signer)) {
            throw new Error(`Invalid signer address provided: ${signer}`);
        }
        const normalized = ethers.utils.getAddress(signer);
        if (!normalizedSigners.includes(normalized)) {
            normalizedSigners.push(normalized);
        }
    }

    const thresholdEnv = process.env[thresholdKey];
    let threshold = thresholdEnv
        ? Number(thresholdEnv)
        : normalizedSigners.length;
    if (threshold == 0 || threshold > normalizedSigners.length) {
        threshold = normalizedSigners.length;
    }

    await verifyUserConsentOnProd(hre, deployer);

    const implementation = await deploy('ClaimTreasury_Implementation', {
        contract: 'ClaimTreasury',
        from: deployer,
        log: true,
        autoMine: true,
    });

    const claimTreasuryFactory =
        await ethers.getContractFactory('ClaimTreasury');
    const initializeData = claimTreasuryFactory.interface.encodeFunctionData(
        'initialize',
        [treasuryOwner, zkpToken, normalizedSigners, threshold],
    );

    const existingProxy =
        getContractEnvAddress(hre, 'CLAIM_TREASURY_PROXY') || '';

    let proxyAddress: string;

    if (existingProxy) {
        proxyAddress = existingProxy;
        await upgradeEIP1967ProxyAndCall(
            hre,
            deployer,
            proxyAddress,
            implementation.address,
            initializeData,
            'ClaimTreasury',
        );
    } else {
        const proxy = await deploy('ClaimTreasury_Proxy', {
            contract: 'EIP173ProxyWithReceive',
            from: deployer,
            args: [implementation.address, multisig, initializeData],
            log: true,
            autoMine: true,
        });
        proxyAddress = proxy.address;
    }

    const proxyArtifact = await hre.artifacts.readArtifact(
        'EIP173ProxyWithReceive',
    );
    await save('ClaimTreasury_Proxy', {
        address: proxyAddress,
        abi: proxyArtifact.abi,
    });

    const treasuryArtifact = await hre.artifacts.readArtifact('ClaimTreasury');
    await save('ClaimTreasury', {
        address: proxyAddress,
        abi: treasuryArtifact.abi,
    });
};

export default func;

func.tags = ['claim-treasury', 'core', 'protocol-v1'];
