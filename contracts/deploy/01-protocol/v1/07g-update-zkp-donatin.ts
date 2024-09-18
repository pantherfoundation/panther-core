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

    const txTypes = [
        '0x100',
        '0x103',
        '0x104',
        '0x105',
        '0x115',
        '0x125',
        '0x135',
        '0x106',
    ];
    const donateAmounts = [
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
    ];

    console.log('updating donation amounts...');

    const tx = await feeMaster.updateDonations(txTypes, donateAmounts, {
        gasPrice: 30000000000,
    });
    const res = await tx.wait();

    console.log('donation amounts are updated!', res.transactionHash);
};
export default func;

func.tags = ['update-zkp-donation', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
