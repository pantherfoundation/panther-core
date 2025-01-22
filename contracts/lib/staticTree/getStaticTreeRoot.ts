// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {poseidon} from 'circomlibjs';
import {BigNumber} from 'ethers';

import {
    ProvidersKeys,
    testnetLeafs as providersKeyLeafs,
} from './providersKeys';
import {ZAssetsRegistry, leafs as zAssetsLeafs} from './zAssetsRegistry';
import {
    ZNetworksRegistry,
    testnetLeafs as zNetworkLeafs,
} from './zNetworksRegistry';
import {ZZonesRegistry, leafs as zZoneLeafs} from './zZonesRegistry';

const blacklistZAccountRoot =
    '0x2a7c7c9b6ce5880b9f6f228d72bf6a575a526f29c66ecceef8b753d38bba7323';

function computeRegistryRoot(leafs: any, RegistryClass: any) {
    const registry = new RegistryClass(leafs);
    registry.computeCommitments();
    registry.getInsertionInputs();
    return registry.root;
}

export function getStaticTreeRoot(network: string) {
    const zAssetsRoot = computeRegistryRoot(
        zAssetsLeafs(network),
        ZAssetsRegistry,
    );
    const zNetworkRoot = computeRegistryRoot(
        Object.values(zNetworkLeafs),
        ZNetworksRegistry,
    );
    const zZoneRoot = computeRegistryRoot(
        Object.values(zZoneLeafs),
        ZZonesRegistry,
    );
    const providersKeyRoot = computeRegistryRoot(
        Object.values(providersKeyLeafs),
        ProvidersKeys,
    );

    console.log({
        zAssetsRoot,
        zNetworkRoot,
        zZoneRoot,
        providersKeyRoot,
    });

    const staticTreeRoot = poseidon([
        zAssetsRoot,
        blacklistZAccountRoot,
        zNetworkRoot,
        zZoneRoot,
        providersKeyRoot,
    ]);
    console.log('staticTreeRoot', BigNumber.from(staticTreeRoot).toHexString());
}

getStaticTreeRoot('amoy');
