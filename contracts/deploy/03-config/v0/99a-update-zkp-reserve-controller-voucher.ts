// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumber} from 'ethers';
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {VOUCHER_TERMS} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

interface VoucherTerms {
    name: string;
    type: string;
    allowedContract: string;
    amount: BigNumber;
    enabled: boolean;
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const pantherPoolV1Deployment = await get('PantherPoolV1');
    const pantherPoolV1 = await ethers.getContractAt(
        'PrpVoucherController',
        pantherPoolV1Deployment.address,
    );

    const newZkpReserveController = (await get('ZkpReserveController')).address;

    // Old ZkpReserveController address
    const oldZkpReserveController =
        '0xf87ab51098BB4E3D44F0695B5D1Ff0Af7c84f9d1';

    const voucherTerms: VoucherTerms[] = [
        {
            name: 'ZkpRelease-disable-old',
            type: '0x53a1eb85',
            allowedContract: oldZkpReserveController,
            amount: VOUCHER_TERMS.zkpRelease,
            enabled: false,
        },
        {
            name: 'ZkpRelease-enable-new',
            type: '0x53a1eb85',
            allowedContract: newZkpReserveController,
            amount: VOUCHER_TERMS.zkpRelease,
            enabled: true,
        },
    ];

    // Generate transactions for all voucher terms
    for (const {name, type, allowedContract, amount, enabled} of voucherTerms) {
        const limit = amount.mul(100);

        const tx = await pantherPoolV1.populateTransaction.updateVoucherTerms(
            allowedContract,
            type,
            limit,
            amount,
            enabled,
        );

        const transaction = createSafeTransaction(
            pantherPoolV1Deployment.address,
            tx.data!,
        );

        await saveSafeTransaction(hre, transaction, __filename, name);
    }
};
export default func;

func.tags = [
    'config',
    'config:vouchers',
    'config:update-zkp-reserve-controller-voucher',
];
