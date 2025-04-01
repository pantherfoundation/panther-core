// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumber} from 'ethers';
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('PrpVoucherController');
    const {address} = await get('PantherPoolV1');
    const pantherPoolV1 = await ethers.getContractAt(abi, address);

    const paymaster = (await get('Paymaster_Proxy')).address;
    const feeMaster = (await get('FeeMaster_Proxy')).address;
    const zkpReserveController = (await get('ZkpReserveController')).address;

    const voucherTerms = [
        {
            name: 'Onboarding',
            type: '0x93b212ae',
            allowedContract: pantherPoolV1.address,
            amount: ethers.BigNumber.from(50),
        },
        {
            name: 'ZkpRelease',
            type: '0x53a1eb85',
            allowedContract: zkpReserveController,
            amount: ethers.BigNumber.from(20),
        },
        {
            name: 'ZkpDistribute',
            type: '0xd48cb9c0',
            allowedContract: feeMaster,
            amount: ethers.BigNumber.from(10),
        },
        {
            name: 'FeeExchange',
            type: '0x1d91a712',
            allowedContract: feeMaster,
            amount: ethers.BigNumber.from(10),
        },
        {
            name: 'PaymasterRefund',
            type: '0x3002a002',
            allowedContract: paymaster,
            amount: ethers.BigNumber.from(10),
        },
    ];

    const updateVoucherTerms = async (
        name: string,
        type: string,
        allowedContract: string,
        amount: BigNumber,
    ) => {
        const limit = amount.mul(100);
        const enabled = true;

        console.log(`Updating ${name} voucher terms`);
        const tx = await pantherPoolV1.updateVoucherTerms(
            allowedContract,
            type,
            limit,
            amount,
            enabled,
            {gasPrice: GAS_PRICE},
        );
        const res = await tx.wait();
        console.log(`${name} voucher terms updated`, res.transactionHash);
    };

    // Update all voucher terms
    for (const {name, type, allowedContract, amount} of voucherTerms) {
        await updateVoucherTerms(name, type, allowedContract, amount);
    }
};
export default func;

func.tags = ['update-voucher-terms', 'core', 'protocol-v1'];
func.dependencies = [
    'add-prp-voucher-controller',
    'fee-master',
    'paymaster-proxy',
    'zkp-reserve-controller',
];
