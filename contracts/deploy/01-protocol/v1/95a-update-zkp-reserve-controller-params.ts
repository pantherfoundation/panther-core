// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ZkpReserveController');
    const {address} = await get('ZkpReserveController');
    const zkpReserveController = await ethers.getContractAt(abi, address);

    const releasablePerBlock = ethers.utils.parseEther('1');
    const minRewardedAmount = ethers.utils.parseEther('500');

    console.log('updating zkp reserve controller params...');

    const tx = await zkpReserveController.updateParams(
        releasablePerBlock,
        minRewardedAmount,
        {gasPrice: 30000000000},
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
