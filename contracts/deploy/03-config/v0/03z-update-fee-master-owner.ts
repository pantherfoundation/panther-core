// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const multisig = await getNamedAccount(hre, 'multisig');
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {address} = await get('FeeMaster_Proxy');

    const feeMasterProxy = await ethers.getContractAt(
        'EIP173ProxyWithReceive',
        address,
    );

    const tx =
        await feeMasterProxy.populateTransaction.transferOwnership(multisig);

    const transaction = createSafeTransaction(feeMasterProxy.address, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};
export default func;

func.tags = ['config', 'config:fee-master', 'config:update-fee-master-owner'];
