// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE, FEE_MASTER} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('FeeMaster');
    const {address} = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(abi, address);

    console.log('updating protocol fee distribution params...');

    const tx = await feeMaster.updateProtocolZkpFeeDistributionParams(
        FEE_MASTER.treasuryLockPercentage,
        FEE_MASTER.minRewardableZkpAmount,
        {gasPrice: GAS_PRICE},
    );
    const res = await tx.wait();

    console.log(
        'protocol fee distribution params is updated!',
        res.transactionHash,
    );
};
export default func;

func.tags = ['update-protocol-fee-distribution-params', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
