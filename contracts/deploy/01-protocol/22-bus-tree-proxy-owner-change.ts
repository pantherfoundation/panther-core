// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    if (!isProd(hre)) return;

    const {ethers} = hre;

    const busTreeProxy = await ethers.getContract('PantherBusTree_Proxy');

    const oldOwner = await busTreeProxy.owner();
    if (oldOwner.toLowerCase() == multisig.toLowerCase()) {
        console.log(`BusTree_Proxy owner is already set to: ${multisig}`);
    } else {
        console.log(
            `Transferring ownership of BusTree_Proxy to ${multisig}...`,
        );

        const signer = await ethers.getSigner(deployer);
        const tx = await busTreeProxy
            .connect(signer)
            .transferOwnership(multisig);

        console.log('BusTree_Proxy owner is updated, tx: ', tx.hash);
    }
};

export default func;

func.tags = ['bus-tree-owner', 'protocol'];
func.dependencies = ['check-params', 'bus-tree'];
