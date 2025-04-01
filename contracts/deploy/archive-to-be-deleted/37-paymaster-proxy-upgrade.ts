// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    getNamedAccount,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const paymasterProxyAddress = await getContractEnvAddress(
        hre,
        'PAYMASTER_PROXY',
    );

    const paymasterImplAddress = await getContractEnvAddress(
        hre,
        'PAYMASTER_IMPL',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        paymasterProxyAddress,
        paymasterImplAddress,
        'paymaster',
    );
};

export default func;

func.tags = ['erc4337', 'paymaster-upgrade'];

func.dependencies = ['check-params', 'deployment-consent'];
