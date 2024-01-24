// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal} from '../../lib/checkNetwork';
import {
    getContractAddress,
    getPZkpToken,
    logInfo,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!isLocal(hre)) return;

    const mockFxPortal = await getContractAddress(hre, 'MockFxPortal', '');
    const pZkp = await getPZkpToken(hre);

    logInfo(
        `Access Fx Portal at ${mockFxPortal} to mint pZkp at ${pZkp.address}`,
    );

    const pZkpTx = await pZkp.setMinter(mockFxPortal);
    const pZkpRes = await pZkpTx.wait();
    const pZkpTxHash = pZkpRes.transactionHash;

    logInfo(`Tx is confirmed ${pZkpTxHash}`);
};

export default func;

func.tags = ['access-fx-portal-to-mint-pzkp', 'dev-dependency'];
func.dependencies = ['mock-fx-portal'];
