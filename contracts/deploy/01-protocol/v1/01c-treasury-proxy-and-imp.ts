// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const treasuryClaimer = await getNamedAccount(hre, 'treasuryClaimer');
    const zkpToken = await getNamedAccount(hre, 'pzkp');

    console.log({multisig, treasuryClaimer, zkpToken});

    const {
        deployments: {deploy},
    } = hre;

    await deploy('ProtocolTreasury', {
        from: deployer,
        args: [multisig, zkpToken, treasuryClaimer],
        proxy: {
            proxyContract: 'EIP173ProxyWithReceive',
            owner: multisig,
        },
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['treasury-proxy', 'core', 'protocol-v1', 'protocol-v1-deploy'];
