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

    const perUtxoReward = ethers.utils.parseEther('0.1');
    const perKytFee = ethers.utils.parseEther('5');
    const kycFee = ethers.utils.parseEther('25');
    const protocolFeePercentage = '250';

    console.log('updating fee params...');

    const tx = await feeMaster.updateFeeParams(
        perUtxoReward,
        perKytFee,
        kycFee,
        protocolFeePercentage,
        {gasPrice: 30000000000},
    );
    const res = await tx.wait();

    console.log('fee params is updated!', res.transactionHash);
};
export default func;

func.tags = ['update-fee-params', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
