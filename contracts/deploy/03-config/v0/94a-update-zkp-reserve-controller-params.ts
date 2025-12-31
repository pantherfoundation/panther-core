// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {ZKP_RESERVE_CONTROLLER} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const zkpReserveControllerDeployment = await get('ZkpReserveController');
    const zkpReserveController = await ethers.getContractAt(
        'ZkpReserveController',
        zkpReserveControllerDeployment.address,
    );

    const tx = await zkpReserveController.populateTransaction.updateParams(
        ZKP_RESERVE_CONTROLLER.releasablePerBlock,
        ZKP_RESERVE_CONTROLLER.minRewardedAmount,
    );

    const transaction = createSafeTransaction(
        zkpReserveControllerDeployment.address,
        tx.data!,
    );

    await saveSafeTransaction(hre, transaction, __filename);
};
export default func;

func.tags = [
    'config',
    'config:zkp-reserve',
    'config:update-zkp-reserve-controller-params',
];
