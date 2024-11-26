// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    await deploy('ZkpReserveController', {
        from: deployer,
        args: [multisig, pzkp, coreDiamond],
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['zkp-reserve-controller', 'core', 'protocol-v1'];
func.dependencies = ['core-diamond'];
