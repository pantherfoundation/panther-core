// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE, PAYMASTER} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('PayMaster_Implementation');
    const {address} = await get('Paymaster_Proxy');

    const paymaster = await ethers.getContractAt(abi, address);

    console.log('Adding paymaster stake');

    const tx = await paymaster.addStake(PAYMASTER.unstakeDelaySec, {
        value: PAYMASTER.addStakeValue,
        gasPrice: GAS_PRICE,
    });
    const res = await tx.wait();

    console.log('Stake is added!', res.transactionHash);
};

export default func;

func.tags = ['paymaster-add-stake'];
func.dependencies = ['upgrade-paymaster-proxy'];
