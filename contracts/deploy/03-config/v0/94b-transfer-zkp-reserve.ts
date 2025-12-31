// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';
import {ZKP_RESERVE_CONTROLLER} from '../mainnet-parameters';
import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const zkpReserveController = (await get('ZkpReserveController')).address;

    const pZkp = await ethers.getContractAt('MockPZkp', pzkp);

    const tx = await pZkp.populateTransaction.transfer(
        zkpReserveController,
        ZKP_RESERVE_CONTROLLER.zkpTokenReserves,
    );

    const transaction = createSafeTransaction(pzkp, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};
export default func;

func.tags = ['config', 'config:zkp-reserve', 'config:transfer-zkp-reserve'];
