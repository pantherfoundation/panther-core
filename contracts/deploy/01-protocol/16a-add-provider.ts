// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress, getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;
    const deployer = await getNamedAccount(hre, 'deployer');

    const {artifacts, ethers} = hre;

    const providersKeyAddress = await getContractAddress(
        hre,
        'ProvidersKeys',
        '',
    );

    const {abi} = await artifacts.readArtifact('ProvidersKeys');
    const providersKeys = await ethers.getContractAt(abi, providersKeyAddress);

    const tx = await providersKeys.addKeyring(deployer, 20);
    const res = await tx.wait();

    console.log('Provider is added to ProvidersKeys', res.transactionHash);
};
export default func;

func.tags = ['add-provider', 'forest', 'protocol'];
func.dependencies = ['providers-keys'];
