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

    const twap = '30';

    console.log('updating twap...');

    const tx = await feeMaster.updateTwapPeriod(twap, {gasPrice: 30000000000});
    const res = await tx.wait();

    console.log('twap is updated!', res.transactionHash);
};
export default func;

func.tags = ['update-twap', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
