// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE, ACCOUNT} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    await deploy('Account', {
        from: deployer,
        // TODO: delete proxy
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: deployer,
        },
        args: [
            [
                coreDiamond,
                coreDiamond,
                coreDiamond,
                coreDiamond,
                coreDiamond,
                coreDiamond,
                ACCOUNT.ADDRESS_ONE,
                ACCOUNT.ADDRESS_ONE,
            ],
            [
                ACCOUNT.zTxnMain.selector,
                ACCOUNT.prpConversion.selector,
                ACCOUNT.voucherController.selector,
                ACCOUNT.zAccountRegistration.selector,
                ACCOUNT.zSwap.selector,
                ACCOUNT.zAccountRenewal.selector,
                ACCOUNT.BYTES_ONE,
                ACCOUNT.BYTES_ONE,
            ],
            [
                ACCOUNT.zTxnMain.payCompOffset,
                ACCOUNT.prpConversion.payCompOffset,
                ACCOUNT.voucherController.payCompOffset,
                ACCOUNT.zAccountRegistration.payCompOffset,
                ACCOUNT.zSwap.payCompOffset,
                ACCOUNT.zAccountRenewal.payCompOffset,
                0,
                0,
            ],
        ],
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });
};
export default func;

func.tags = ['account'];
func.dependencies = ['core-diamond'];
