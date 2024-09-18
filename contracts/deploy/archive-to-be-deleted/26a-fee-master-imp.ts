// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    getNamedAccount,
    getPZkpToken,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const weth9 = await getNamedAccount(hre, 'weth9');

    const {
        deployments: {deploy},
    } = hre;

    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        '',
    );
    const pantherBusTree = await getContractAddress(
        hre,
        'PantherBusTree_Proxy',
        '',
    );

    const pZkp = await getPZkpToken(hre);

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    await deploy('FeeMaster_Implementation', {
        contract: 'FeeMaster',
        from: deployer,
        args: [
            multisig,
            pantherPool,
            pantherBusTree,
            pantherBusTree,
            pZkp.address,
            weth9,
            vaultProxy,
        ],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['fee-master-imp', 'protocol'];
func.dependencies = ['check-params', 'deployment-consent'];
