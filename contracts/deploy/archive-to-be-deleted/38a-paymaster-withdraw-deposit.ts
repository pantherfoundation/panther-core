// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {abi} from '../../external/abi/EntryPoint.json';
import {
    getContractAddress,
    getContractEnvAddress,
    getNamedAccount,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    // INTERNAL AMOY ADDRESSES
    // const paymasterAddress = "0x575427D754dcD72F071F7A0F2c2139AbF36704Ac";
    // const entryPointAddress ="0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
    // PUBLIC AMOY ADDRESSES
    // const paymasterAddress ="0xc0208D4bd3D5Bd48b59339d2ABfB0933e5a09288"
    const entryPointAddress = getContractEnvAddress(hre, 'ENTRY_POINT');
    const paymasterAddress = await getContractAddress(hre, 'PayMaster', '');
    const entryPoint = await ethers.getContractAt(abi, entryPointAddress);

    const depositValue = await entryPoint.balanceOf(paymasterAddress);

    console.log(ethers.utils.formatUnits(depositValue, 18));

    console.log(deployer);

    console.log(
        ethers.utils.formatUnits(await ethers.provider.getBalance(deployer)),
    );

    const {abi: abiPaymaster} = await artifacts.readArtifact('PayMaster');

    const paymaster = await ethers.getContractAt(
        abiPaymaster,
        paymasterAddress,
    );

    console.log(paymaster.address);

    console.log(
        `PAYMASTER DEPOSIT ${ethers.utils.formatUnits(
            await entryPoint.balanceOf(paymaster.address),
            18,
        )}`,
    );

    const BYTES32_ONE =
        '0x0000000000000000000000000000000000000000000000000000000000000001';

    const tx = await paymaster.claimEthAndRefundEntryPoint(BYTES32_ONE, {
        gasLimit: 1e6,
    });

    console.log(tx.hash);

    await tx.wait();

    console.log(
        `PAYMASTER DEPOSIT ${ethers.utils.formatUnits(
            await entryPoint.balanceOf(paymaster.address),
            18,
        )}`,
    );

    // console.log(
    //     ethers.utils.formatUnits(await ethers.provider.getBalance(deployer)),
    // );
};

export default func;

func.tags = ['erc4337', 'paymaster-withdraw-deposit'];

func.dependencies = ['check-params', 'deployment-consent'];
