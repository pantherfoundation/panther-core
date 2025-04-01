// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

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
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['paymaster-imp', 'protocol-v1'];
func.dependencies = ['account', 'fee-master', 'core-diamond'];
