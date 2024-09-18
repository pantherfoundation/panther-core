// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

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
            gasPrice: 30000000000,
        });
        const res = await tx.wait();
        console.log('owner is updated, tx: ', res.transactionHash);
    }
};
export default func;

func.tags = ['update-fee-master-owner', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
