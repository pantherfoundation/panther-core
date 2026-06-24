// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {getGasPrice} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
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
        args: [multisig, entryPoint, account, feeMaster, coreDiamond],
        log: true,
        autoMine: true,
        gasPrice: await getGasPrice(hre),
    });
};
export default func;

func.tags = ['paymaster-imp', 'protocol-v1', 'protocol-v1-deploy'];
func.dependencies = ['account', 'fee-master-proxy', 'core-diamond'];
