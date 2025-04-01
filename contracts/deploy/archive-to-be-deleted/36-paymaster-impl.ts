// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    reuseEnvAddress,
    getNamedAccount,
    getContractEnvAddress,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    if (reuseEnvAddress(hre, 'PAYMSTER')) return;

    const entryPointAddress = getContractEnvAddress(hre, 'ENTRY_POINT');

    const accountAddress = getContractEnvAddress(hre, 'ACCOUNT');

    const feeMasterAddress = getContractEnvAddress(hre, 'FEE_MASTER');

    const prpVoucherGrantorAddress = await getContractEnvAddress(
        hre,
        'PRP_VOUCHER_GRANTOR',
    );

    await deploy('PayMaster_Implementation', {
        contract: 'PayMaster',
        from: deployer,
        args: [
            entryPointAddress,
            accountAddress,
            feeMasterAddress,
            prpVoucherGrantorAddress,
        ],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['erc4337', 'paymaster-impl'];
func.dependencies = ['check-params', 'deployment-consent'];
