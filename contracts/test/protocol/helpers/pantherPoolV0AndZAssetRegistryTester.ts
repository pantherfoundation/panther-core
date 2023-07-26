// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// @ts-ignore
import {PantherPoolV0AndZAssetRegistryTester} from '../../types/contracts';

import {getPantherPoolMocFactoryByName} from './pantherPoolMockFactory';

export {deployPantherPoolV0AndZAssetRegistryTester};

async function deployPantherPoolV0AndZAssetRegistryTester(): Promise<PantherPoolV0AndZAssetRegistryTester> {
    const PantherPoolV0 = await getPantherPoolMocFactoryByName(
        'PantherPoolV0AndZAssetRegistryTester',
    );

    return (await (
        await PantherPoolV0.deploy()
    ).deployed()) as PantherPoolV0AndZAssetRegistryTester;
}
