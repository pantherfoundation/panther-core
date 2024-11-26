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

    console.log('updating native reserves target...');

    const tx = await feeMaster.updateNativeTokenReserveTarget(
        FEE_MASTER.nativeTokenReserveTarget,
        {gasPrice: GAS_PRICE},
    );
    const res = await tx.wait();

    console.log('native reserves target is updated!', res.transactionHash);
};
export default func;

func.tags = ['update-native-reserves-target', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
