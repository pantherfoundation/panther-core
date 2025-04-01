// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {maxBlocktimeOffset, GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('AppConfiguration');
    const {address} = await get('PantherPoolV1');
    const diamond = await ethers.getContractAt(abi, address);

    console.log('updating max blocktime offset');

    const tx = await diamond.updateMaxBlockTimeOffset(maxBlocktimeOffset, {
        gasPrice: GAS_PRICE,
    });
    const res = await tx.wait();

    console.log('max blocktime offset is updated', res.transactionHash);
};
export default func;

func.tags = ['update-max-blocktime-offset', 'core', 'protocol-v1'];
func.dependencies = ['add-app-configuration'];
