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

    const nativeTokenReserves = ethers.utils.parseEther('0.5');

    console.log('transfering native tokens...');

    const tx = await feeMaster.increaseNativeTokenReserves({
        value: nativeTokenReserves,
        gasPrice: 30000000000,
    });
    const res = await tx.wait();

    console.log('native tokens are transfered', res.transactionHash);
};
export default func;

func.tags = ['transfer-fee-master-native-reserves', 'core', 'protocol-v1'];
func.dependencies = ['fee-master', 'add-fee-master-total-debt-controller'];
