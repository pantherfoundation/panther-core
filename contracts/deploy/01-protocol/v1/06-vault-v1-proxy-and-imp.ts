// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy, get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    await deploy('VaultV1', {
        from: deployer,
        args: [coreDiamond],
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

func.tags = ['vault-v1', 'core', 'protocol-v1'];
func.dependencies = ['core-diamond'];
