// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getNamedAccount,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    await verifyUserConsentOnProd(hre, deployer);

    await deploy('PantherVerifier', {
        from: deployer,
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['verifier', 'forest', 'zwallet', 'protocol'];
