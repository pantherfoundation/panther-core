// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy, save},
    } = hre;

    const implementation = await deploy('ClaimTreasury_Implementation', {
        contract: 'ClaimTreasury',
        from: deployer,
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });

    const proxy = await deploy('ClaimTreasury_Proxy', {
        contract: 'EIP173ProxyWithReceive',
        from: deployer,
        args: [implementation.address, multisig, '0x'],
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });

    const treasuryArtifact = await hre.artifacts.readArtifact('ClaimTreasury');
    await save('ClaimTreasury', {
        address: proxy.address,
        abi: treasuryArtifact.abi,
    });
};

export default func;

func.tags = ['treasury-proxy', 'core', 'protocol-v1'];
