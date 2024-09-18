// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
    } = hre;

    const treesDiamond = (await get('PantherTrees')).address;
    const vaultV1 = (await get('VaultV1')).address;
    const feeMaster = (await get('FeeMaster')).address;
    const poseidonT3 = (await get('PoseidonT3')).address;

    await deploy('ZSwap', {
        from: deployer,
        args: [treesDiamond, vaultV1, feeMaster, pzkp],
        libraries: {PoseidonT3: poseidonT3},
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = ['zswap', 'core', 'core-facet', 'protocol-v1'];
func.dependencies = [
    'poseidon-libs-v1',
    'trees-diamond',
    'vault-v1',
    'fee-master',
];
