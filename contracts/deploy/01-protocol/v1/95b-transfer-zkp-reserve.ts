// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE, ZKP_RESERVE_CONTROLLER} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const zkpReserveController = (await get('ZkpReserveController')).address;

    const pZkp = await ethers.getContractAt('MockPZkp', pzkp);

    console.log('transfering zkp tokens...');
    const tx = await pZkp.transfer(
        zkpReserveController,
        ZKP_RESERVE_CONTROLLER.zkpTokenReserves,
        {
            gasPrice: GAS_PRICE,
        },
    );
    const res = await tx.wait();

    console.log('zkp tokens are transfered', res.transactionHash);
};
export default func;

func.tags = [
    'transfer-zkp-reserve-controller-zkp-tokens',
    'core',
    'protocol-v1',
];
func.dependencies = ['zkp-reserve-controller'];
