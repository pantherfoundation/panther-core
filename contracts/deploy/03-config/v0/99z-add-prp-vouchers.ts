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

    const paymaster = (await get('Paymaster_Proxy')).address;
    const feeMaster = (await get('FeeMaster_Proxy')).address;
    const zkpReserveController = (await get('ZkpReserveController')).address;

    const voucherTerms: VoucherTerms[] = [
        {
            name: 'Onboarding',
            type: '0x93b212ae',
            allowedContract: pantherPoolV1Deployment.address,
            amount: VOUCHER_TERMS.onboarding,
        },
        {
            name: 'ZkpRelease',
            type: '0x53a1eb85',
            allowedContract: zkpReserveController,
            amount: VOUCHER_TERMS.zkpRelease,
        },
        {
            name: 'ZkpDistribute',
            type: '0xd48cb9c0',
            allowedContract: feeMaster,
            amount: VOUCHER_TERMS.zkpDistribute,
        },
        {
            name: 'FeeExchange',
            type: '0x1d91a712',
            allowedContract: feeMaster,
            amount: VOUCHER_TERMS.feeExchange,
        },
        {
            name: 'PaymasterRefund',
            type: '0x3002a002',
            allowedContract: paymaster,
            amount: VOUCHER_TERMS.paymasterRefund,
        },
    ];

    // Generate transactions for all voucher terms
    for (const {name, type, allowedContract, amount} of voucherTerms) {
        const limit = amount.mul(100);
        const enabled = true;

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

func.tags = ['config', 'config:vouchers', 'config:add-prp-vouchers'];
