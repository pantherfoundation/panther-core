// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {promises} from 'fs';
import {join} from 'path';

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {deployContentDeterministically} from '../../../lib/deploymentHelpers';
import {encodeVerificationKey} from '../../../lib/encodeVerificationKey';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const prpConversionVKFilePath = join(
        __dirname,
        `../../../test/protocol/data/verificationKeys/VK_prpConversion.json`,
    );
    const prpAccountingVKFilePath = join(
        __dirname,
        `../../../test/protocol/data/verificationKeys/VK_prpAccounting.json`,
    );
    const zAccountRegistrationVKFilePath = join(
        __dirname,
        `../../../test/protocol/data/verificationKeys/VK_zAccountsRegistration.json`,
    );
    const zAccountRenewalVKFilePath = join(
        __dirname,
        `../../../test/protocol/data/verificationKeys/VK_zAccountsRenewal.json`,
    );
    const zSwapVKFilePath = join(
        __dirname,
        `../../../test/protocol/data/verificationKeys/VK_zswap.json`,
    );
    const zTransactionVKFilePath = join(
        __dirname,
        `../../../test/protocol/data/verificationKeys/VK_ztransaction.json`,
    );

    const busTreeUpdaterVKFilePath = join(
        __dirname,
        `../../../test/protocol/data/verificationKeys/VK_pantherBusTreeUpdater.json`,
    );

    const verificationKeys: {key?: string; pointer?: string}[] = [];

    {
        console.log('deploying prp conversion vk...');

        const verificationKey = JSON.parse(
            await promises.readFile(prpConversionVKFilePath, {
                encoding: 'utf8',
            }),
        );

        const {pointer, isReused} = await deployContentDeterministically(
            hre,
            encodeVerificationKey(verificationKey),
        );

        verificationKeys.push({key: 'prpConversion', pointer});

        if (isReused) console.log('prp conversion vk was already deployed!');
    }

    {
        console.log('deploying prp accounting vk...');

        const verificationKey = JSON.parse(
            await promises.readFile(prpAccountingVKFilePath, {
                encoding: 'utf8',
            }),
        );

        const {pointer, isReused} = await deployContentDeterministically(
            hre,
            encodeVerificationKey(verificationKey),
        );

        verificationKeys.push({key: 'prpAccounting', pointer});

        if (isReused) console.log('prp accounting vk was already deployed!');
    }

    {
        console.log('deploying zAccount registration vk...');

        const verificationKey = JSON.parse(
            await promises.readFile(zAccountRegistrationVKFilePath, {
                encoding: 'utf8',
            }),
        );

        const {pointer, isReused} = await deployContentDeterministically(
            hre,
            encodeVerificationKey(verificationKey),
        );

        verificationKeys.push({key: 'zAccountRegistration', pointer});

        if (isReused)
            console.log('zAccount registration vk was already deployed!');
    }

    {
        console.log('deploying zAccount renewal vk...');

        const verificationKey = JSON.parse(
            await promises.readFile(zAccountRenewalVKFilePath, {
                encoding: 'utf8',
            }),
        );

        const {pointer, isReused} = await deployContentDeterministically(
            hre,
            encodeVerificationKey(verificationKey),
        );

        verificationKeys.push({key: 'zAccountRenewal', pointer});

        if (isReused) console.log('zAccount renewal vk was already deployed!');
    }

    {
        console.log('deploying zSwap vk...');

        const verificationKey = JSON.parse(
            await promises.readFile(zSwapVKFilePath, {
                encoding: 'utf8',
            }),
        );

        const {pointer, isReused} = await deployContentDeterministically(
            hre,
            encodeVerificationKey(verificationKey),
        );

        verificationKeys.push({key: 'zSwap', pointer});

        if (isReused) console.log('zSwap vk was already deployed!');
    }

    {
        console.log('deploying zTransaction vk...');

        const verificationKey = JSON.parse(
            await promises.readFile(zTransactionVKFilePath, {
                encoding: 'utf8',
            }),
        );

        const {pointer, isReused} = await deployContentDeterministically(
            hre,
            encodeVerificationKey(verificationKey),
        );

        verificationKeys.push({key: 'zTransaction', pointer});

        if (isReused) console.log('zTransaction vk was already deployed!');
    }

    {
        console.log('deploying bus tree updater vk...');

        const verificationKey = JSON.parse(
            await promises.readFile(busTreeUpdaterVKFilePath, {
                encoding: 'utf8',
            }),
        );

        const {pointer, isReused} = await deployContentDeterministically(
            hre,
            encodeVerificationKey(verificationKey),
        );

        verificationKeys.push({key: 'busTreeUpdater', pointer});

        if (isReused) console.log('bus tree updater vk was already deployed!');
    }

    process.env.VERIFICATION_KEY_POINTERS = JSON.stringify(verificationKeys);
};

export default func;

func.tags = ['verifications-keys', 'core', 'protocol-v1'];
