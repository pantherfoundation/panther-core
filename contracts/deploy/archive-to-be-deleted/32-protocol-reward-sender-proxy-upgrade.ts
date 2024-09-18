// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

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
func.dependencies = ['deployment-consent', 'protocol-reward-sender-imp'];
