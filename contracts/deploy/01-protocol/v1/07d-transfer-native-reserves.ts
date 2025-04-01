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

    console.log('transfering native tokens...');

    const tx = await feeMaster.increaseNativeTokenReserves({
        value: FEE_MASTER.nativeTokenReserves,
        gasPrice: GAS_PRICE,
    });
    const res = await tx.wait();

    console.log('native tokens are transfered', res.transactionHash);
};
export default func;

func.tags = ['transfer-fee-master-native-reserves', 'core', 'protocol-v1'];
func.dependencies = ['fee-master', 'add-fee-master-total-debt-controller'];
