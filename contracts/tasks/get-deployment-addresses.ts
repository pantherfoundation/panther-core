// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {task} from 'hardhat/config';
import {DeploymentsExtension} from 'hardhat-deploy/types';

task(
    'get-deployed-addresses',
    'Prints all deployed contract addresses in {deploymentName: address} format',
).setAction(async (_, hre) => {
    const deployments: DeploymentsExtension = hre.deployments;
    const allDeployments = await deployments.all();

    const deployedAddresses: Record<string, string> = {};

    for (const [name, deployment] of Object.entries(allDeployments)) {
        if (deployment.address) {
            deployedAddresses[name] = deployment.address;
        }
    }

    console.log(JSON.stringify(deployedAddresses, null, 2));
});
