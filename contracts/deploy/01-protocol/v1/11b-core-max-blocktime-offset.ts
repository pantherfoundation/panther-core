// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('AppConfiguration');
    const {address} = await get('PantherPoolV1');
    const diamond = await ethers.getContractAt(abi, address);

    const maxBlocktimeOffset = '600'; // 5 mins

    console.log('updating max blocktime offset');

    const tx = await diamond.updateMaxBlockTimeOffset(maxBlocktimeOffset);
    const res = await tx.wait();

    console.log('max blocktime offset is updated', res.transactionHash);
};
export default func;

func.tags = ['update-max-blocktime-offset', 'core', 'protocol-v1'];
func.dependencies = ['add-app-configuration'];
