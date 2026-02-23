// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    createSafeTransaction,
    saveSafeTransaction,
    BRIDGE_ADDRESSES,
    fxRootAbi,
} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {address: vaultProxyAddress} = await get('VaultV1_Proxy');
    const {address: vaultImplAddress} = await get('VaultV1_Implementation');

    const vaultProxy = await ethers.getContractAt(
        'EIP173ProxyWithReceive',
        vaultProxyAddress,
    );

    // For cross-chain execution, we need to prepare the bridge transaction
    const fxRoot = await ethers.getContractAt(
        fxRootAbi,
        BRIDGE_ADDRESSES.fxRoot,
    );

    // The current nonce. must be updated. it can be found in the `maticBridgeModuleAddress` contract
    const maticBridgeModuleNonce = 53;

    const tx_upgradeTo =
        await vaultProxy.populateTransaction.upgradeTo(vaultImplAddress);

    const encodedBridgeData = hre.ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint256', 'bytes', 'uint8', 'uint256'],
        [vaultProxy.address, 0, tx_upgradeTo.data, 0, maticBridgeModuleNonce],
    );

    const fxRootCalldata = await fxRoot.populateTransaction.sendMessageToChild(
        BRIDGE_ADDRESSES.maticBridgeModule,
        encodedBridgeData,
    );

    const transaction = createSafeTransaction(
        BRIDGE_ADDRESSES.fxRoot,
        fxRootCalldata.data!,
    );

    await saveSafeTransaction(hre, transaction, __filename);

    console.log('=== VaultV1 Upgrade Transaction Generated ===');
    console.log('Target contract (VaultV1_Proxy):', vaultProxy.address);
    console.log('New implementation:', vaultImplAddress);
    console.log('Transaction saved for multisig execution');
};
export default func;

func.tags = [
    'config-v1',
    'config-v1:vault',
    'config-v1:upgrade-vault-v1-proxy',
];
