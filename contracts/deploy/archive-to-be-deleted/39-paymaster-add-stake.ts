// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumber} from 'ethers';
import {DeployFunction} from 'hardhat-deploy/types';

import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction =
    async function (/*hre: HardhatRuntimeEnvironment*/) {
        const addStakeValue = process.env.ADD_STAKE_VALUE;

        if (!addStakeValue) {
            console.error(
                'Error: ADD_STAKE_VALUE environment variable is not provided.',
            );
            process.exit(1);
        }

        const paymasterProxyAddr = await getContractAddress(
            hre,
            'Paymaster_Proxy',
            'PAYMASTER_PROXY',
        );

        const {abi} = await artifacts.readArtifact('PayMaster');

        const paymaster = await ethers.getContractAt(abi, paymasterProxyAddr);

        // set unstake timeout to 1 hour
        const tx = await paymaster.addStake(BigNumber.from(3600), {
            value: ethers.utils.parseEther(addStakeValue),
        });

        await tx.wait();
    };

export default func;

// func.tags = ['erc4337', 'paymaster-add-stake'];

// func.dependencies = ['check-params', 'deployment-consent'];
