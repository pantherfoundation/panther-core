// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const depositValue = process.env.DEPOSIT_VALUE;

    if (!depositValue) {
        console.error(
            'Error: DEPOSIT_VALUE environment variable is not provided.',
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

    const tx = await paymaster.depositToEntryPoint({
        value: ethers.utils.parseEther(depositValue),
    });

    await tx.wait();
};

export default func;

func.tags = ['erc4337', 'paymaster-add-deposit'];

func.dependencies = ['check-params', 'deployment-consent'];
