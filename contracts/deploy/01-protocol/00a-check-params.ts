// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {fulfillExistingContractAddresses} from '../../lib/deploymentHelpers';

const scaledConvertibleZkp = 1e6;
const scaledMinerRewards = 1e6;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {network} = hre;

    fulfillExistingContractAddresses(hre);

    console.log(`Deploying on ${network.name}...`);

    process.env['MINER_REWARDS'] = hre.ethers.utils.parseEther(
        scaledMinerRewards.toString(),
    );

    process.env['CONVERTIBLE_ZKP'] = hre.ethers.utils.parseEther(
        scaledConvertibleZkp.toString(),
    );
};

export default func;

func.tags = ['check-params'];
