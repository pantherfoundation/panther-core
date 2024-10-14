// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

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

    {
        console.log('Updating onboarding voucher terms');

        const onboardingType = '0x93b212ae';

        const allowedContract = pantherPoolV1.address;
        const amount = ethers.BigNumber.from(5000);
        const limit = amount.mul(10000000);
        const enabled = true;

        const tx = await pantherPoolV1.updateVoucherTerms(
            allowedContract,
            onboardingType,
            limit,
            amount,
            enabled,
            {gasPrice: 30000000000},
        );

        const res = await tx.wait();
        console.log('Onboarding voucher terms is updated', res.transactionHash);
    }

    {
        console.log('Updating zkpRelease voucher terms');

        const zkpReleaseType = '0x53a1eb85';

        const allowedContract = zkpReserveController;
        const amount = ethers.BigNumber.from(3000);
        const limit = amount.mul(10000000);
        const enabled = true;

        const tx = await pantherPoolV1.updateVoucherTerms(
            allowedContract,
            zkpReleaseType,
            limit,
            amount,
            enabled,
            {gasPrice: 30000000000},
        );

        const res = await tx.wait();
        console.log('ZkpRelease voucher terms is updated', res.transactionHash);
    }

    {
        console.log('Updating zkpDistribute voucher terms');

        const zkpDistributeType = '0xd48cb9c0';

        const allowedContract = feeMaster;
        const amount = ethers.BigNumber.from(3000);
        const limit = amount.mul(10000000);
        const enabled = true;

        const tx = await pantherPoolV1.updateVoucherTerms(
            allowedContract,
            zkpDistributeType,
            limit,
            amount,
            enabled,
            {gasPrice: 30000000000},
        );

        const res = await tx.wait();
        console.log(
            'ZkpDistribute voucher terms is updated',
            res.transactionHash,
        );
    }

    {
        console.log('Updating feeExchange voucher terms');

        const feeExchangeType = '0x1d91a712';

        const allowedContract = feeMaster;
        const amount = ethers.BigNumber.from(4000);
        const limit = amount.mul(10000000);
        const enabled = true;

        const tx = await pantherPoolV1.updateVoucherTerms(
            allowedContract,
            feeExchangeType,
            limit,
            amount,
            enabled,
            {gasPrice: 30000000000},
        );

        const res = await tx.wait();
        console.log(
            'FeeExchange voucher terms is updated',
            res.transactionHash,
        );
    }

    {
        console.log('Updating paymasterRefund voucher terms');

        const paymasterRefundType = '0x3002a002';

        const allowedContract = paymaster;
        const amount = ethers.BigNumber.from(1000);
        const limit = amount.mul(10000000);
        const enabled = true;

        const tx = await pantherPoolV1.updateVoucherTerms(
            allowedContract,
            paymasterRefundType,
            limit,
            amount,
            enabled,
            {gasPrice: 30000000000},
        );

        const res = await tx.wait();
        console.log(
            'PaymasterRefund voucher terms is updated',
            res.transactionHash,
        );
    }
};
export default func;

func.tags = ['update-voucher-terms', 'core', 'protocol-v1'];
func.dependencies = [
    'add-prp-voucher-controller',
    'fee-master',
    'paymaster-proxy',
];
