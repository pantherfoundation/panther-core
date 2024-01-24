// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    verifyUserConsentOnProd,
    getContractAddress,
    getNamedAccount,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const {
        deployments: {deploy},
    } = hre;

    await verifyUserConsentOnProd(hre, deployer);

    const pantherPoolV1Proxy = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        '',
    );

    await deploy('PrpVoucherGrantor', {
        from: deployer,
        args: [multisig, pantherPoolV1Proxy],
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: multisig,
        },
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['prp-voucher-grantor', 'protocol'];
func.dependencies = ['pool-v1-proxy'];
