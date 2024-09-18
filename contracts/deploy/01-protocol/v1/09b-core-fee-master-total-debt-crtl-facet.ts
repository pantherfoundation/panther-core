// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
    } = hre;

    const vaultV1 = (await get('VaultV1')).address;
    const feeMaster = (await get('FeeMaster')).address;

    await deploy('FeeMasterTotalDebtController', {
        from: deployer,
        args: [vaultV1, feeMaster],
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = [
    'fee-master-total-debt-controller',
    'core',
    'core-facet',
    'protocol-v1',
];
func.dependencies = ['vault-v1', 'fee-master'];
