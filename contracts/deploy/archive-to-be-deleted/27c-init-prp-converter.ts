// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    getPZkpToken,
    logInfo,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {ethers, artifacts} = hre;

    const prpConverterAddress = await getContractAddress(
        hre,
        'PrpConverter_Proxy',
        '',
    );

    const {abi} = await artifacts.readArtifact('PrpConverter');
    const prpConverter = await ethers.getContractAt(abi, prpConverterAddress);

    const zkpAmount = process.env.CONVERTIBLE_ZKP as string;

    const prpVirtualAmount = ethers.BigNumber.from(zkpAmount).div(
        ethers.utils.parseUnits('1', 17),
    );

    console.log('initialize prp converter');
    const isInitialized = await prpConverter.initialized();

    const pZkp = await getPZkpToken(hre);

    if (!isInitialized) {
        const data = ethers.utils.defaultAbiCoder.encode(
            ['uint256'],
            [zkpAmount],
        );

        logInfo(
            `Minting ${ethers.utils.formatEther(zkpAmount)} to PrpConverter`,
        );
        await pZkp.deposit(prpConverter.address, data);

        logInfo(`Initializing the PrpConverter`);

        const tx = await prpConverter.initPool(prpVirtualAmount, zkpAmount);
        const res = await tx.wait();

        console.log('Transaction confirmed', res.transactionHash);
    }
};

export default func;

func.tags = ['init-prp-converter', 'protocol'];
func.dependencies = ['prp-converter-proxy', 'check-params'];
