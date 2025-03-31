// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal} from '../../lib/checkNetwork';
import {
    fulfillLocalAddress,
    fulfillExistingContractAddresses,
    getContractEnvAddress,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts, network} = hre;
    fulfillExistingContractAddresses(hre);

    console.log(`Deploying on ${network.name}...`);

    const {deployer} = await getNamedAccounts();
    if (!deployer) throw 'Err: deployer undefined';

    if (!isLocal(hre)) {
        if (!getContractEnvAddress(hre, 'ZKP_TOKEN'))
            throw `Undefined ZKP_TOKEN_${hre.network.name.toUpperCase}`;

        if (!process.env.DAO_MULTISIG_ADDRESS)
            throw 'Undefined DAO_MULTISIG_ADDRESS';
    } else {
        if (!fulfillLocalAddress(hre, 'ZKP_TOKEN'))
            throw 'Undefined ZKP_TOKEN_LOCALHOST';
    }
};

export default func;

func.tags = ['check-params-staking'];
