// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
    } = hre;

    const feeMaster = (await get('FeeMaster_Proxy')).address;
    const payMaster = (await get('Paymaster_Proxy')).address;
    const zkpReserveController = (await get('ZkpReserveController')).address;
    const coreDiamond = (await get('PantherPoolV1')).address;

    await deploy('PrpRewardEstimator', {
        from: deployer,
        args: [feeMaster, payMaster, zkpReserveController, coreDiamond],
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = [
    'prp-reward-estimator',
    'core',
    'protocol-v1',
    'protocol-v1-deploy',
];
func.dependencies = [
    'core-diamond',
    'fee-master-proxy',
    'paymaster-proxy',
    'zkp-reserve-controller',
];
