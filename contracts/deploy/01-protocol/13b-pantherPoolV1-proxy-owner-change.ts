// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {
    getContract,
    getNamedAccount,
    logInfo,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!isProd(hre)) return;
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {ethers} = hre;

    const pantherPoolV1Proxy = await getContract(
        hre,
        'PantherPoolV1_Proxy',
        '',
    );

    const oldOwner = await pantherPoolV1Proxy.owner();

    if (oldOwner.toLowerCase() == multisig.toLowerCase()) {
        logInfo(`PantherPoolV1Proxy owner is already set to: ${multisig}`);
    } else {
        logInfo(
            `Transferring ownership of PantherPoolV1Proxy to ${multisig}...`,
        );

        const signer = await ethers.getSigner(deployer);
        const tx = await pantherPoolV1Proxy
            .connect(signer)
            .transferOwnership(multisig);

        logInfo(`PantherPoolV1Proxy owner is updated, tx: ${tx.hash}`);
    }
};

export default func;

func.tags = ['pool-v1-owner', 'protocol'];
func.dependencies = ['pool-v1-proxy', 'deployment-consent'];
