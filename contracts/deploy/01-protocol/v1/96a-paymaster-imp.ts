// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const entryPoint = await getNamedAccount(hre, 'entryPoint');

    const {
        deployments: {deploy, get},
    } = hre;

    const account = (await get('Account')).address;
    const feeMaster = (await get('FeeMaster')).address;
    const coreDiamond = (await get('PantherPoolV1')).address;

    await deploy('PayMaster_Implementation', {
        contract: 'PayMaster',
        from: deployer,
        args: [entryPoint, account, feeMaster, coreDiamond],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['paymaster-imp', 'protocol-v1'];
func.dependencies = ['account', 'fee-master', 'core-diamond'];
