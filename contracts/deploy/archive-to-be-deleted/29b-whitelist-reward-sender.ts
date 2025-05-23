// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {artifacts, ethers} = hre;

    const protocolRewardControllerAddress = await getContractAddress(
        hre,
        'ProtocolRewardController_Proxy',
        '',
    );
    const rewardSenderAddress = await getContractAddress(
        hre,
        'ToPolygonZkpTokenAndPrpRewardMsgSender_Proxy',
        '',
    );

    const {abi} = await artifacts.readArtifact('ProtocolRewardController');

    const protocolRewardController = await ethers.getContractAt(
        abi,
        protocolRewardControllerAddress,
    );

    console.log('whitelist sender...');

    const tx = await protocolRewardController.updateRewardSender(
        rewardSenderAddress,
        true,
    );
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['whitelist-reward-sender'];
func.dependencies = ['protocol-reward-ctrl', 'reward-sender-proxy'];
