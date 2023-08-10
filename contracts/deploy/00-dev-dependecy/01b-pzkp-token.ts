// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    abi,
    bytecode,
} from '../../deployments/ARCHIVE/externalAbis/PZkpToken.json';
import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();

    const MockFxPortalProxy = await getContractAddress(
        hre,
        'MockFxPortal_Proxy',
        '',
    );

    await deploy('PZkp_token', {
        contract: {
            abi,
            bytecode,
        },
        from: deployer,
        args: [MockFxPortalProxy],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['pzkp-token', 'dev-dependency'];
