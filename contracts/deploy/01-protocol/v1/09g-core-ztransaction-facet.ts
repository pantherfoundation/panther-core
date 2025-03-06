// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
    } = hre;

    const treesDiamond = (await get('PantherTrees')).address;
    const vaultV1 = (await get('VaultV1')).address;
    const feeMaster = (await get('FeeMaster')).address;
    const poseidonT4 = (await get('PoseidonT4')).address;

    await deploy('ZTransaction', {
        from: deployer,
        args: [treesDiamond, vaultV1, feeMaster, pzkp],
        libraries: {PoseidonT4: poseidonT4},
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['ztransaction', 'core', 'core-facet', 'protocol-v1'];
func.dependencies = ['trees-diamond', 'vault-v1', 'fee-master'];
