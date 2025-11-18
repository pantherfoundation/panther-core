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
    const zkpToken = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const claimTreasury = await get('ClaimTreasury');

    // Default signers: use treasury owner or fallback to multisig
    const initialSigners = [treasuryOwner ?? multisig];
    const threshold = 1;

    const claimTreasuryContract = await ethers.getContractAt(
        'ClaimTreasury',
        claimTreasury.address,
    );

    const tx = await claimTreasuryContract.initialize(
        treasuryOwner,
        zkpToken,
        initialSigners,
        threshold,
        {
            from: deployer,
            gasPrice: GAS_PRICE,
        },
    );
    await tx.wait();
    console.log('ClaimTreasury initialized');
};
export default func;

func.tags = ['treasury-init', 'core', 'protocol-v1'];
func.dependencies = ['treasury-proxy'];
