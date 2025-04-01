// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE, ZKP_RESERVE_CONTROLLER} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZkpReserveController');
    const {address} = await get('ZkpReserveController');
    const zkpReserveController = await ethers.getContractAt(abi, address);

    console.log('updating zkp reserve controller params...');

    const tx = await zkpReserveController.updateParams(
        ZKP_RESERVE_CONTROLLER.releasablePerBlock,
        ZKP_RESERVE_CONTROLLER.minRewardedAmount,
        {gasPrice: GAS_PRICE},
    );
    const res = await tx.wait();

    console.log(
        'zkp reserve controller params are updated!',
        res.transactionHash,
    );
};
export default func;

func.tags = ['update-zkp-reserve-controller-params', 'core', 'protocol-v1'];
func.dependencies = ['zkp-reserve-controller'];
