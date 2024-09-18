// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('FeeMaster');
    const {address} = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(abi, address);

    const treasuryLockPercentage = 10 * 100; // 10%
    const minRewardableZkpAmount = ethers.utils.parseEther('10');

    console.log('updating protocol fee distribution params...');

    const tx = await feeMaster.updateProtocolZkpFeeDistributionParams(
        treasuryLockPercentage,
        minRewardableZkpAmount,
        {gasPrice: 30000000000},
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
