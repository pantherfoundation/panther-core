// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const staticTreeAddress = await getContractAddress(
        hre,
        'PantherStaticTree_Proxy',
        '',
    );

    const {abi} = await artifacts.readArtifact('PantherStaticTree');
    const staticTree = await ethers.getContractAt(abi, staticTreeAddress);

    const root = await staticTree.getRoot();
    if (
        root ==
        '0x0000000000000000000000000000000000000000000000000000000000000000'
    ) {
        console.log('initialize panther static tree', root);

        const tx = await staticTree.initialize();
        const res = await tx.wait();
        console.log('Transaction confirmed', res.transactionHash);
    } else {
        console.log('static tree is already initialized', root);
    }
};

export default func;

func.tags = ['init-static', 'protocol'];
