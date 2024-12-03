// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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

    console.log('updating fee params...');

    const tx = await feeMaster.updateFeeParams(
        FEE_MASTER.FEE_PARAMS.perUtxoReward,
        FEE_MASTER.FEE_PARAMS.perKytFee,
        FEE_MASTER.FEE_PARAMS.kycFee,
        FEE_MASTER.FEE_PARAMS.protocolFeePercentage,
        {gasPrice: GAS_PRICE},
    );
    const res = await tx.wait();

    console.log('fee params is updated!', res.transactionHash);
};
export default func;

func.tags = ['update-fee-params', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
