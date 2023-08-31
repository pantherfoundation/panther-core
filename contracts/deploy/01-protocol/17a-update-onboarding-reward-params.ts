// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

// TODO To be deleted after implementing panther pool v1
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const onboardingControllerAddress = await getContractAddress(
        hre,
        'OnboardingController_Proxy',
        '',
    );

    const {abi} = await artifacts.readArtifact('OnboardingController');

    const onboardingController = await ethers.getContractAt(
        abi,
        onboardingControllerAddress,
    );

    console.log('Updating onboarding reward params');

    const zkpAmount = 0;
    const zZkpAmount = ethers.utils.parseEther('100');

    const tx = await onboardingController.updateRewardParams(
        zkpAmount,
        zZkpAmount,
    );
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['update-onboarding-reward-params', 'protocol'];
