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

    console.log('updating donation amounts...');

    const tx = await feeMaster.updateDonations(
        FEE_MASTER.txTypes,
        FEE_MASTER.donateAmounts,
        {
            gasPrice: GAS_PRICE,
        },
    );
    const res = await tx.wait();

    console.log('donation amounts are updated!', res.transactionHash);
};
export default func;

func.tags = ['update-zkp-donation', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
