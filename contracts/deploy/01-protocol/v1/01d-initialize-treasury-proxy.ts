// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const treasuryOwner = await getNamedAccount(hre, 'pantherTreasury');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const treasury = await get('Treasury');

    // Default claimer: use treasury owner or fallback to multisig
    const claimer = treasuryOwner ?? multisig;

    const treasuryContract = await ethers.getContractAt(
        'Treasury',
        treasury.address,
    );

    // Check if already initialized
    const isInitialized = await treasuryContract
        .claimer()
        .then(() => true)
        .catch(() => false);

    if (!isInitialized) {
        const tx = await treasuryContract.initialize(claimer, {
            from: deployer,
            gasPrice: GAS_PRICE,
        });
        await tx.wait();
        console.log('Treasury initialized');
    } else {
        console.log('Treasury already initialized, skipping');
    }
};
export default func;

func.tags = ['treasury-init', 'core', 'protocol-v1'];
func.dependencies = ['treasury-proxy'];
