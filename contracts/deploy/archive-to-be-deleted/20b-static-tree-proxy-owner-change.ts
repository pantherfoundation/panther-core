// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!isProd(hre)) return;
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const pantherStaticTreeProxy = await ethers.getContract(
        'PantherStaticTree_Proxy',
    );

    const oldOwner = await pantherStaticTreeProxy.owner();
    if (oldOwner.toLowerCase() == multisig.toLowerCase()) {
        console.log(
            `PantherStaticTree_Proxy owner is already set to: ${multisig}`,
        );
    } else {
        console.log(
            `Transferring ownership of PantherStaticTree_Proxy to ${multisig}...`,
        );

        const signer = await ethers.getSigner(deployer);
        const tx = await pantherStaticTreeProxy
            .connect(signer)
            .transferOwnership(multisig);

        console.log('PantherStaticTree_Proxy owner is updated, tx: ', tx.hash);
    }
};

export default func;

func.tags = ['z-accounts-registry-owner', 'protocol'];
func.dependencies = ['deployment-consent', 'static-tree-proxy'];
