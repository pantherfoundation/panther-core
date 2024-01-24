// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';
import {isLocal, isProd} from '../../lib/checkNetwork';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {getNamedAccounts} = hre;
    const {deployer} = await getNamedAccounts();

    const polygonZkpTokenAndPrpRewardMsgSenderProxy = await getContractAddress(
        hre,
        'ToPolygonZkpTokenAndPrpRewardMsgSender_Proxy',
        '',
    );
    const polygonZkpTokenAndPrpRewardMsgSenderImpl = await getContractAddress(
        hre,
        'ToPolygonZkpTokenAndPrpRewardMsgSender_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        polygonZkpTokenAndPrpRewardMsgSenderProxy,
        polygonZkpTokenAndPrpRewardMsgSenderImpl,
        'polygonZkpTokenAndPrpRewardMsgSender',
    );
};

export default func;

func.tags = ['protocol-reward-sender-upgrade', 'protocol'];
