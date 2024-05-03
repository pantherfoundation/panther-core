// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getNamedAccount,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const prpConverterProxy = await getContractAddress(
        hre,
        'PrpConverter_Proxy',
        '',
    );
    const prpConverterImpl = await getContractAddress(
        hre,
        'PrpConverter_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        prpConverterProxy,
        prpConverterImpl,
        'PrpConverter',
    );
};

export default func;

func.tags = ['prp-converter-upgrade', 'protocol'];
func.dependencies = [
    'deployment-consent',
    'prp-converter-proxy',
    'prp-converter-imp',
];
