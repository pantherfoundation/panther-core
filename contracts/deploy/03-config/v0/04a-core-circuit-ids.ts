// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const pantherPoolV1 = await get('PantherPoolV1');
    const diamond = await ethers.getContractAt(
        'AppConfiguration',
        pantherPoolV1.address,
    );

    const verificationKeys = JSON.parse(
        process.env.VERIFICATION_KEY_POINTERS as string,
    );

    const txTypes = {
        zAccountRegistration: '0x100',
        zAccountReactivation: '0x101',
        zAccountRenewal: '0x102',
        prpAccounting: '0x103',
        prpConversion: '0x104',
        zTransaction: '0x105',
        zSwap: '0x106',
    };

    const circuitUpdates = [
        {key: 'zAccountRegistration', txType: txTypes.zAccountRegistration},
        {key: 'zAccountReactivation', txType: txTypes.zAccountReactivation},
        {key: 'zAccountRenewal', txType: txTypes.zAccountRenewal},
        {key: 'prpAccounting', txType: txTypes.prpAccounting},
        {key: 'prpConversion', txType: txTypes.prpConversion},
        {key: 'zTransaction', txType: txTypes.zTransaction},
        {key: 'zSwap', txType: txTypes.zSwap},
    ];

    for (const {key, txType} of circuitUpdates) {
        const pointer = hre.ethers.BigNumber.from(
            verificationKeys.filter((x: any) => x.key === key)[0].pointer,
        );

        const tx = await diamond.populateTransaction.updateCircuitId(
            txType,
            pointer,
        );

        const transaction = createSafeTransaction(
            pantherPoolV1.address,
            tx.data!,
        );

        await saveSafeTransaction(hre, transaction, __filename, key);
    }
};
export default func;

func.tags = ['config', 'config:core', 'config:update-circuit-ids'];
