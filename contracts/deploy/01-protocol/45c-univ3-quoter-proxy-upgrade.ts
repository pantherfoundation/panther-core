// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    getNamedAccount,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const proxyAddr = await getContractEnvAddress(
        hre,
        'UNI_V3_QUOTER_V2_PROXY_INTERNAL',
    );

    const implAddr = await getContractEnvAddress(
        hre,
        'UNI_V3_QUOTER_V2_IMPL_INTERNAL',
    );

    console.log(proxyAddr);
    console.log(implAddr);

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        proxyAddr,
        implAddr,
        'UNI_V3_QUOTER_V2_PROXY_INTERNAL',
    );
};

export default func;

func.tags = ['univ3-quoter-proxy-upgrade'];
func.dependencies = ['check-params', 'deployment-consent'];
