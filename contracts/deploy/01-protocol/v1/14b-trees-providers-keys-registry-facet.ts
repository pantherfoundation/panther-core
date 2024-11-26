// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
    } = hre;

    const keyringVersion = 1;
    const treesDiamond = (await get('PantherTrees')).address;

    const poseidonT3 = (await get('PoseidonT3')).address;
    const poseidonT4 = (await get('PoseidonT4')).address;

    await deploy('ProvidersKeysRegistry', {
        from: deployer,
        args: [treesDiamond, keyringVersion],
        libraries: {PoseidonT3: poseidonT3, PoseidonT4: poseidonT4},
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['providers-keys-registry', 'trees', 'trees-facet', 'protocol-v1'];
func.dependencies = ['poseidon-libs-v1', 'trees-diamond'];
