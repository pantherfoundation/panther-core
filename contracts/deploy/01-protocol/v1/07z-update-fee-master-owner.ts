// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const multisig = await getNamedAccount(hre, 'multisig');
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {address, abi} = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(abi, address);

    console.log('updating fee master owner...');

    const oldOwner = await feeMaster.owner();

    if (oldOwner.toLowerCase() == multisig.toLowerCase()) {
        console.log(`owner is already set to: ${multisig}`);
    } else {
        console.log(`transferring ownership to ${multisig}...`);

        const tx = await feeMaster.transferOwnership(multisig, {
            gasPrice: GAS_PRICE,
        });
        const res = await tx.wait();
        console.log('owner is updated, tx: ', res.transactionHash);
    }
};
export default func;

func.tags = ['update-fee-master-owner', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
