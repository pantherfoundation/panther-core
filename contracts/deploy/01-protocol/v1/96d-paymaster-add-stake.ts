// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const unstakeDelaySec = 87400;
    const addStakeValue = ethers.utils.parseEther('5');

    const {abi} = await get('PayMaster_Implementation');
    const {address} = await get('Paymaster_Proxy');

    const paymaster = await ethers.getContractAt(abi, address);

    console.log('Adding paymaster stake');

    const tx = await paymaster.addStake(unstakeDelaySec, {
        value: addStakeValue,
        gasPrice: 30000000000,
    });
    const res = await tx.wait();

    console.log('Stake is added!', res.transactionHash);
};

export default func;

func.tags = ['paymaster-add-stake'];
func.dependencies = ['upgrade-paymaster-proxy'];
