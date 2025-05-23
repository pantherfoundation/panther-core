// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {artifacts, ethers} = hre;

    const pzkpAddress = await getContractAddress(
        hre,
        'PZkp_token',
        'PZKP_TOKEN',
    );

    const mockChildChainManagerProxy = await getContractAddress(
        hre,
        'MockChildChainManager_Proxy',
        '',
    );

    const {abi} = await artifacts.readArtifact('IPZkp');
    const pZkp = await ethers.getContractAt(abi, pzkpAddress);

    console.log('Changing Minter');

    const tx = await pZkp.setMinter(mockChildChainManagerProxy);
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['set-pzkp-minter'];
