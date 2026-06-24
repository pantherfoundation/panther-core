// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getGasPrice} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('FeeMaster_Implementation');
    const {address} = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(abi, address);

    console.log('apprving vault by FeeMaster...');

    const tx = await feeMaster.approveVaultToTransferZkp({
        gasPrice: await getGasPrice(hre),
    });
    const res = await tx.wait();

    console.log('vault is approved by FeeMaster', res.transactionHash);
};
export default func;

func.tags = ['approve-vault-by-fee-master', 'core', 'protocol-v1'];
func.dependencies = ['upgrade-fee-master'];
