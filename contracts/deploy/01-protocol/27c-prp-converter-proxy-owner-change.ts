// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!isProd(hre)) return;
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const prpConverterProxy = await ethers.getContract('PrpConverter_Proxy');

    const oldOwner = await prpConverterProxy.owner();
    if (oldOwner.toLowerCase() == multisig.toLowerCase()) {
        console.log(`PrpConverter_Proxy owner is already set to: ${multisig}`);
    } else {
        console.log(
            `Transferring ownership of PrpConverter_Proxy to ${multisig}...`,
        );

        const signer = await ethers.getSigner(deployer);
        const tx = await prpConverterProxy
            .connect(signer)
            .transferOwnership(multisig);

        console.log('PrpConverter_Proxy owner is updated, tx: ', tx.hash);
    }
};

export default func;

func.tags = ['prp-converter-owner-change', 'protocol'];
func.dependencies = ['deployment-consent', 'static-tree-proxy'];
