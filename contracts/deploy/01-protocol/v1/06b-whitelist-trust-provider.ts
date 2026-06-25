// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getGasPrice, COMPLIANCE_TREASURY} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        artifacts,
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await artifacts.readArtifact('ComplianceTreasury');
    const {address} = await get('ComplianceTreasury_Proxy');
    const complianceTreasury = await ethers.getContractAt(abi, address);

    const desiredTrustProvider = COMPLIANCE_TREASURY.trustProvider;
    const currentTrustProvider = await complianceTreasury.trustProvider();

    if (
        currentTrustProvider.toLowerCase() ===
        desiredTrustProvider.toLowerCase()
    ) {
        console.log(
            `trust provider already set to ${desiredTrustProvider}, skipping...`,
        );
        return;
    }

    console.log(`updating trust provider to ${desiredTrustProvider}...`);

    const tx = await complianceTreasury.updateTrustProvider(
        desiredTrustProvider,
        {gasPrice: await getGasPrice(hre)},
    );
    const res = await tx.wait();

    console.log('trust provider updated! tx:', res.transactionHash);
};
export default func;

func.tags = ['whitelist-trust-provider', 'core', 'protocol-v1'];
func.dependencies = ['compliance-treasury'];
